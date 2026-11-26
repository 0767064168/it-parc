import { useEffect, useState, type FormEvent } from 'react';
import { Check, ClipboardList, Clock3, PackageCheck, RefreshCw, Send, X } from 'lucide-react';
import { apiRequest } from './api';
import { useAuth } from './auth';

type RequestStatus = 'soumise' | 'en_examen' | 'approuvee' | 'refusee' | 'livree';
type RequestCategory =
  | 'ordinateur_portable'
  | 'ordinateur_fixe'
  | 'ecran'
  | 'telephone'
  | 'accessoire'
  | 'autre';

type EquipmentRequest = {
  id: number;
  requester_display_name: string;
  requester_current_username?: string;
  category: RequestCategory;
  description?: string | null;
  justification: string;
  priority: 'basse' | 'moyenne' | 'haute';
  status: RequestStatus;
  decision_comment?: string | null;
  asset_id?: number | null;
  asset_tag?: string | null;
  created_at: string;
};

type AvailableAsset = {
  id: number;
  asset_tag: string;
  marque?: string | null;
  modele?: string | null;
};

const categoryLabels: Record<RequestCategory, string> = {
  ordinateur_portable: 'Ordinateur portable',
  ordinateur_fixe: 'Ordinateur fixe',
  ecran: 'Écran',
  telephone: 'Téléphone',
  accessoire: 'Accessoire',
  autre: 'Autre matériel',
};

const statusLabels: Record<RequestStatus, string> = {
  soumise: 'Soumise',
  en_examen: 'En examen',
  approuvee: 'Approuvée',
  refusee: 'Refusée',
  livree: 'Livrée',
};

const statusTones: Record<RequestStatus, string> = {
  soumise: 'request-status-pending',
  en_examen: 'request-status-review',
  approuvee: 'request-status-approved',
  refusee: 'request-status-rejected',
  livree: 'request-status-delivered',
};

export function EquipmentRequestsPage() {
  const { token, user } = useAuth();
  const isReviewer = user?.role === 'admin' || user?.role === 'technicien';
  const [requests, setRequests] = useState<EquipmentRequest[]>([]);
  const [availableAssets, setAvailableAssets] = useState<AvailableAsset[]>([]);
  const [category, setCategory] = useState<RequestCategory>('ordinateur_portable');
  const [description, setDescription] = useState('');
  const [justification, setJustification] = useState('');
  const [priority, setPriority] = useState<'basse' | 'moyenne' | 'haute'>('moyenne');
  const [comments, setComments] = useState<Record<number, string>>({});
  const [selectedAssets, setSelectedAssets] = useState<Record<number, string>>({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [feedback, setFeedback] = useState('');

  async function loadRequests() {
    setLoading(true);
    setError('');
    try {
      const data = await apiRequest<EquipmentRequest[]>('/equipment-requests', { token });
      setRequests(data);
      if (isReviewer) {
        const assets = await apiRequest<AvailableAsset[]>('/equipment-requests/available-assets', { token });
        setAvailableAssets(assets);
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Impossible de charger les demandes.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadRequests();
  }, [token, isReviewer]);

  async function submitRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError('');
    setFeedback('');
    try {
      await apiRequest<EquipmentRequest>('/equipment-requests', {
        token,
        method: 'POST',
        body: { category, description: description.trim(), justification: justification.trim(), priority },
      });
      setDescription('');
      setJustification('');
      setPriority('moyenne');
      setFeedback('Votre demande a été envoyée.');
      await loadRequests();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Impossible d’envoyer la demande.');
    } finally {
      setSubmitting(false);
    }
  }

  async function changeStatus(request: EquipmentRequest, status: RequestStatus) {
    setError('');
    setFeedback('');
    const assetValue = selectedAssets[request.id];
    try {
      await apiRequest<unknown>(`/equipment-requests/${request.id}/status`, {
        token,
        method: 'PATCH',
        body: {
          status,
          comment: comments[request.id]?.trim() || undefined,
          ...(status === 'livree' ? { asset_id: Number(assetValue) } : {}),
        },
      });
      setFeedback(`Demande #${request.id} : ${statusLabels[status].toLowerCase()}.`);
      await loadRequests();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Impossible de mettre à jour la demande.');
    }
  }

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">PORTAIL COLLABORATEUR</span>
          <h1>Demandes de matériel</h1>
          <p>Soumettez une demande et suivez sa validation par l’équipe IT.</p>
        </div>
        <div className="heading-actions">
          <button type="button" className="button button-secondary" onClick={() => void loadRequests()} disabled={loading}>
            <RefreshCw size={15} /> Actualiser
          </button>
        </div>
      </div>

      {error && <div className="alert alert-error" role="alert">{error}</div>}
      {feedback && <div className="alert alert-success" role="status">{feedback}</div>}

      <div className="equipment-requests-layout">
        <section className="panel equipment-request-form-panel">
          <div className="panel-heading">
            <div>
              <h2><Send size={17} /> Nouvelle demande</h2>
              <p>Les demandes sont visibles par l’équipe IT pour validation.</p>
            </div>
          </div>
          <form className="equipment-request-form" onSubmit={(event) => void submitRequest(event)}>
            <label>
              Matériel souhaité
              <select className="input" value={category} onChange={(event) => setCategory(event.target.value as RequestCategory)}>
                {Object.entries(categoryLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
            </label>
            <label>
              Détails souhaités <span className="muted">(facultatif)</span>
              <textarea className="input" rows={3} maxLength={1000} value={description} onChange={(event) => setDescription(event.target.value)} placeholder="Modèle, caractéristiques ou accessoires..." />
            </label>
            <label>
              Priorité
              <select className="input" value={priority} onChange={(event) => setPriority(event.target.value as typeof priority)}>
                <option value="basse">Basse</option>
                <option value="moyenne">Moyenne</option>
                <option value="haute">Haute</option>
              </select>
            </label>
            <label>
              Justification
              <textarea className="input" rows={4} minLength={10} maxLength={2000} required value={justification} onChange={(event) => setJustification(event.target.value)} placeholder="Expliquez le besoin professionnel..." />
            </label>
            <button type="submit" className="button button-primary" disabled={submitting}>
              <Send size={15} /> {submitting ? 'Envoi...' : 'Envoyer la demande'}
            </button>
          </form>
        </section>

        <section className="panel equipment-request-list-panel">
          <div className="panel-heading">
            <div>
              <h2><ClipboardList size={18} /> {isReviewer ? 'Demandes à traiter' : 'Mes demandes'}</h2>
              <p>{requests.length} demande{requests.length === 1 ? '' : 's'}</p>
            </div>
          </div>
          {loading ? (
            <div className="loading-lines"><i /><i /><i /></div>
          ) : requests.length === 0 ? (
            <div className="empty-state">Aucune demande pour le moment.</div>
          ) : (
            <div className="equipment-request-list">
              {requests.map((request) => (
                <article className="equipment-request-card" key={request.id}>
                  <div className="equipment-request-card-header">
                    <div>
                      <strong>{categoryLabels[request.category] || request.category}</strong>
                      <span className="equipment-request-id">Demande #{request.id}</span>
                    </div>
                    <span className={`equipment-request-status ${statusTones[request.status]}`}>{statusLabels[request.status]}</span>
                  </div>
                  <div className="equipment-request-meta">
                    {isReviewer && <span>Demandeur : {request.requester_display_name || request.requester_current_username}</span>}
                    <span>Priorité : {request.priority}</span>
                    <span>{new Date(request.created_at).toLocaleDateString('fr-FR')}</span>
                  </div>
                  {request.description && <p className="equipment-request-description">{request.description}</p>}
                  <p className="equipment-request-justification">{request.justification}</p>
                  {request.asset_tag && <p className="equipment-request-asset">Matériel lié : {request.asset_tag}</p>}
                  {request.decision_comment && <p className="equipment-request-comment">Commentaire IT : {request.decision_comment}</p>}

                  {isReviewer && !['refusee', 'livree'].includes(request.status) && (
                    <div className="equipment-request-actions">
                      <textarea
                        className="input"
                        rows={2}
                        maxLength={1000}
                        value={comments[request.id] ?? ''}
                        onChange={(event) => setComments((current) => ({ ...current, [request.id]: event.target.value }))}
                        placeholder="Commentaire de traitement (facultatif)"
                      />
                      {request.status === 'soumise' && (
                        <button type="button" className="button button-secondary" onClick={() => void changeStatus(request, 'en_examen')}>
                          <Clock3 size={14} /> Prendre en charge
                        </button>
                      )}
                      {['soumise', 'en_examen'].includes(request.status) && (
                        <>
                          <button type="button" className="button button-primary" onClick={() => void changeStatus(request, 'approuvee')}>
                            <Check size={14} /> Approuver
                          </button>
                          <button type="button" className="button button-danger" onClick={() => void changeStatus(request, 'refusee')}>
                            <X size={14} /> Refuser
                          </button>
                        </>
                      )}
                      {request.status === 'approuvee' && (
                        <>
                          <select
                            className="input"
                            value={selectedAssets[request.id] ?? ''}
                            onChange={(event) => setSelectedAssets((current) => ({ ...current, [request.id]: event.target.value }))}
                          >
                            <option value="">Choisir l’équipement en stock</option>
                            {availableAssets.map((asset) => (
                              <option key={asset.id} value={asset.id}>
                                {asset.asset_tag}{asset.marque || asset.modele ? ` — ${[asset.marque, asset.modele].filter(Boolean).join(' ')}` : ''}
                              </option>
                            ))}
                          </select>
                          <button
                            type="button"
                            className="button button-primary"
                            disabled={!selectedAssets[request.id]}
                            onClick={() => void changeStatus(request, 'livree')}
                          >
                            <PackageCheck size={14} /> Marquer livrée
                          </button>
                        </>
                      )}
                    </div>
                  )}
                </article>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
