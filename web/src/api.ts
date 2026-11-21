export type ApiEnvelope<T> = {
  success: boolean;
  data: T;
  message?: string;
};

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

const configuredBaseUrl = import.meta.env.VITE_API_BASE_URL?.trim();
const localHosts = new Set(['localhost', '127.0.0.1', '[::1]']);
const defaultBaseUrl =
  localHosts.has(window.location.hostname)
    ? `http://${window.location.hostname}:3000/api`
    : new URL('/api', window.location.origin).toString();
const apiBaseUrl = (configuredBaseUrl || defaultBaseUrl).replace(/\/+$/, '');

function apiUrl(path: string, query?: Record<string, string | number | boolean | undefined>) {
  const url = new URL(`${apiBaseUrl}/${path.replace(/^\/+/, '')}`);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined) url.searchParams.set(key, String(value));
  }
  return url;
}

function unauthorized(response: Response) {
  if (response.status === 401) window.dispatchEvent(new Event('parc-it:unauthorized'));
}

async function errorMessage(response: Response) {
  const payload = (await response.json().catch(() => null)) as { message?: string } | null;
  return payload?.message || `Erreur API HTTP ${response.status}`;
}

export async function apiRequest<T>(
  path: string,
  options: {
    token?: string | null;
    method?: string;
    body?: unknown;
    query?: Record<string, string | number | boolean | undefined>;
  } = {},
): Promise<T> {
  const bodyIsForm = typeof FormData !== 'undefined' && options.body instanceof FormData;
  const headers = new Headers({ Accept: 'application/json' });
  if (options.token) headers.set('Authorization', `Bearer ${options.token}`);
  if (options.body !== undefined && !bodyIsForm) headers.set('Content-Type', 'application/json');

  let response: Response;
  try {
    response = await fetch(apiUrl(path, options.query), {
      method: options.method ?? 'GET',
      headers,
      body: options.body === undefined
        ? undefined
        : bodyIsForm
          ? options.body as FormData
          : JSON.stringify(options.body),
    });
  } catch {
    throw new ApiError(
      'Serveur API injoignable. Vérifiez que l’API tourne sur le port 3000 et que l’origine Web est autorisée.',
      0,
    );
  }

  const payload = (await response.json().catch(() => null)) as
    | ApiEnvelope<T>
    | { message?: string }
    | null;

  unauthorized(response);

  if (!response.ok) {
    throw new ApiError(
      payload && 'message' in payload && payload.message
        ? payload.message
        : `Erreur API HTTP ${response.status}`,
      response.status,
    );
  }

  if (!payload || !('success' in payload) || !payload.success) {
    throw new ApiError(
      payload && 'message' in payload && payload.message
        ? payload.message
        : 'Réponse API invalide',
      response.status,
    );
  }

  return payload.data;
}

export async function apiDownload(
  path: string,
  options: { token?: string | null; query?: Record<string, string | number | boolean | undefined> } = {},
) {
  const headers = new Headers();
  if (options.token) headers.set('Authorization', `Bearer ${options.token}`);
  let response: Response;
  try {
    response = await fetch(apiUrl(path, options.query), { headers });
  } catch {
    throw new ApiError(
      'Serveur API injoignable. Vérifiez que l’API tourne sur le port 3000 et que l’origine Web est autorisée.',
      0,
    );
  }
  unauthorized(response);
  if (!response.ok) throw new ApiError(await errorMessage(response), response.status);
  return response.blob();
}
