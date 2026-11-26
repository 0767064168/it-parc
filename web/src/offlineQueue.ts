import { apiRequest, ApiError } from './api';

export type OfflineActionItem = {
  id: string;
  type: 'AUDIT_SCAN' | 'INCIDENT_REPORT' | 'ASSET_CREATE' | 'ASSET_UPDATE' | 'AFFECTATION_CREATE' | 'TICKET_CREATE';
  endpoint: string;
  method: 'POST' | 'PUT';
  body: Record<string, unknown>;
  label: string;
  createdAt: string;
};

const STORAGE_KEY = 'parc-it-offline-queue';
const MAX_OFFLINE_QUEUE_ITEMS = 100;
export const OFFLINE_QUEUE_EVENT = 'parc-it:offline-queue-changed';
export const OFFLINE_QUEUE_STORAGE_ERROR_EVENT = 'parc-it:offline-queue-storage-error';

export function getOfflineQueue(): OfflineActionItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveOfflineQueue(items: OfflineActionItem[]): boolean {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items.slice(-MAX_OFFLINE_QUEUE_ITEMS)));
    window.dispatchEvent(new Event(OFFLINE_QUEUE_EVENT));
    return true;
  } catch {
    window.dispatchEvent(new Event(OFFLINE_QUEUE_STORAGE_ERROR_EVENT));
    return false;
  }
}

export function enqueueOfflineAction(item: Omit<OfflineActionItem, 'id' | 'createdAt'>): OfflineActionItem {
  const newItem: OfflineActionItem = {
    ...item,
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    createdAt: new Date().toISOString(),
  };
  const current = getOfflineQueue();
  if (!saveOfflineQueue([...current.slice(-(MAX_OFFLINE_QUEUE_ITEMS - 1)), newItem])) {
    return newItem;
  }
  return newItem;
}

export function clearOfflineQueue() {
  saveOfflineQueue([]);
}

export async function syncOfflineQueue(token: string | null): Promise<{ synced: number; failed: number }> {
  const queue = getOfflineQueue();
  if (!queue.length || !token || !navigator.onLine) {
    return { synced: 0, failed: 0 };
  }

  let synced = 0;
  let failed = 0;
  const remaining: OfflineActionItem[] = [];

  for (const item of queue) {
    try {
      await apiRequest(item.endpoint, {
        token,
        method: item.method,
        body: item.body,
      });
      synced += 1;
    } catch (err: unknown) {
      const status = err instanceof ApiError ? err.status : 0;
      const shouldRetry =
        status === 0 ||
        status === 401 ||
        status === 403 ||
        status === 408 ||
        status === 429 ||
        status >= 500;
      if (shouldRetry || !navigator.onLine) {
        remaining.push(item);
        failed += 1;
      } else {
        // Erreur métier (4xx) : on ignore l'élément invalide pour ne pas bloquer la file
        failed += 1;
      }
    }
  }

  saveOfflineQueue(remaining);
  return { synced, failed };
}
