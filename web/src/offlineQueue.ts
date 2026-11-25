import { apiRequest } from './api';

export type OfflineActionItem = {
  id: string;
  type: 'AUDIT_SCAN' | 'INCIDENT_REPORT';
  endpoint: string;
  method: 'POST' | 'PUT';
  body: Record<string, unknown>;
  label: string;
  createdAt: string;
};

const STORAGE_KEY = 'parc-it-offline-queue';
export const OFFLINE_QUEUE_EVENT = 'parc-it:offline-queue-changed';

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

function saveOfflineQueue(items: OfflineActionItem[]) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
    window.dispatchEvent(new Event(OFFLINE_QUEUE_EVENT));
  } catch {
    // ignore storage quota errors
  }
}

export function enqueueOfflineAction(item: Omit<OfflineActionItem, 'id' | 'createdAt'>): OfflineActionItem {
  const newItem: OfflineActionItem = {
    ...item,
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    createdAt: new Date().toISOString(),
  };
  const current = getOfflineQueue();
  saveOfflineQueue([...current, newItem]);
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
      // Si erreur réseau (status === 0), garder en file d'attente
      const isNetworkError = err instanceof Error && 'status' in err && (err as { status: number }).status === 0;
      if (isNetworkError || !navigator.onLine) {
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
