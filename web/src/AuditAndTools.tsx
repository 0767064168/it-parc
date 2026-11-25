import React, { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import {
  Camera,
  ScanLine,
  X,
  Printer,
  PenTool,
  RotateCcw,
  CheckCircle2,
  ClipboardCheck,
  Plus,
  FileSpreadsheet,
  PackageCheck,
  ShieldAlert,
  Mail,
  RefreshCw,
  Search,
  Clock,
  Laptop,
  Download,
  AlertTriangle,
  Ticket,
  UserCheck,
  Settings,
  Save,
} from 'lucide-react';
import { apiDownload, apiRequest } from './api';
import { useAuth } from './auth';
import { enqueueOfflineAction } from './offlineQueue';

// ============================================================================
// 1. SCANNER QR CODE MOBILE & DESKTOP (CAMÉRA)
// ============================================================================
export function QrScannerModal({
  isOpen,
  onClose,
  onScan,
}: {
  isOpen: boolean;
  onClose: () => void;
  onScan: (code: string) => void;
}) {
  const [manualCode, setManualCode] = useState('');
  const [cameraError, setCameraError] = useState('');
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    if (!isOpen) return;
    setCameraError('');
    setManualCode('');

    let stopped = false;
    async function startCamera() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
        });
        if (stopped) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play().catch(() => {});
        }
      } catch (err: unknown) {
        setCameraError("Impossible d'accéder à la caméra (accès refusé ou indisponible). Vous pouvez saisir le code manuellement ci-dessous.");
      }
    }

    void startCamera();

    // BarcodeDetector natif pour Android / Chrome / Edge
    let intervalId: any;
    if (typeof window !== 'undefined' && 'BarcodeDetector' in window) {
      try {
        // @ts-ignore
        const detector = new window.BarcodeDetector({ formats: ['qr_code', 'code_128', 'ean_13'] });
        intervalId = setInterval(async () => {
          if (videoRef.current && videoRef.current.readyState >= 2) {
            try {
              const barcodes = await detector.detect(videoRef.current);
              if (barcodes && barcodes.length > 0 && barcodes[0].rawValue) {
                const code = barcodes[0].rawValue;
                playBeep();
                onScan(code);
                onClose();
              }
            } catch (_) {}
          }
        }, 400);
      } catch (_) {}
    }

    return () => {
      stopped = true;
      if (intervalId) clearInterval(intervalId);
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((t) => t.stop());
        streamRef.current = null;
      }
    };
  }, [isOpen, onScan, onClose]);

  function playBeep() {
    try {
      const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      const audioCtx = new AudioContextClass();
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, audioCtx.currentTime);
      gain.gain.setValueAtTime(0.12, audioCtx.currentTime);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.14);
    } catch (_) {}
  }

  function handleManualSubmit(e: FormEvent) {
    e.preventDefault();
    if (manualCode.trim()) {
      playBeep();
      onScan(manualCode.trim());
      onClose();
    }
  }

  if (!isOpen) return null;

  return (
    <div className="scanner-modal-overlay" onClick={onClose}>
      <div className="scanner-card" onClick={(e) => e.stopPropagation()}>
        <div className="scanner-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <ScanLine size={18} color="#38bdf8" />
            <strong style={{ fontSize: 14 }}>Scanner Caméra QR Code</strong>
          </div>
          <button type="button" className="icon-button" onClick={onClose} style={{ color: '#94a3b8' }}>
            <X size={18} />
          </button>
        </div>

        <div className="scanner-viewport-wrapper">
          <video ref={videoRef} className="scanner-video" playsInline muted />
          <div className="scanner-target-box">
            <div className="scanner-laser" />
          </div>
          {cameraError && (
            <div style={{ position: 'absolute', inset: 0, background: '#020617', padding: 24, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', color: '#94a3b8', fontSize: 12 }}>
              <Camera size={36} color="#ef4444" style={{ marginBottom: 12 }} />
              <p style={{ margin: 0 }}>{cameraError}</p>
            </div>
          )}
        </div>

        <p className="scanner-instructions">
          Centrez le QR Code ou le Code-barres de la machine dans le cadre ci-dessus.
        </p>

        <form className="scanner-manual-input" onSubmit={handleManualSubmit}>
          <input
            type="text"
            placeholder="Ou saisissez le Tag / N° de Série..."
            value={manualCode}
            onChange={(e) => setManualCode(e.target.value)}
            autoFocus
          />
          <button type="submit" className="button button-primary" style={{ padding: '0 16px' }}>
            Valider
          </button>
        </form>
      </div>
    </div>
  );
}

// ============================================================================
// 2. PLANCHE D'IMPRESSION D'ÉTIQUETTES PAR LOT A4 (BATCH LABELS)
// ============================================================================
export function BatchQrLabelsModal({
  isOpen,
  onClose,
  assets,
}: {
  isOpen: boolean;
  onClose: () => void;
  assets: Array<Record<string, unknown>>;
}) {
  const [selectedSite, setSelectedSite] = useState('Tous');

  const filteredAssets = useMemo(() => {
    if (selectedSite === 'Tous') return assets;
    return assets.filter((a) => String(a.site || '').toLowerCase().includes(selectedSite.toLowerCase()));
  }, [assets, selectedSite]);

  if (!isOpen) return null;

  return (
    <div className="batch-labels-modal" onClick={onClose}>
      <div className="batch-labels-container" onClick={(e) => e.stopPropagation()}>
        <div className="batch-labels-toolbar">
          <div>
            <h3 style={{ margin: 0, fontSize: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
              <Printer size={18} color="#0284c7" /> Planche d'étiquettes QR Code A4
            </h3>
            <span style={{ fontSize: 12, color: '#64748b' }}>
              Format normalisé 24 étiquettes / page (3 colonnes x 8 lignes) • {filteredAssets.length} étiquette(s)
            </span>
          </div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <select
              className="select"
              value={selectedSite}
              onChange={(e) => setSelectedSite(e.target.value)}
              style={{ fontSize: 12, padding: '4px 8px' }}
            >
              <option value="Tous">Tous les sites</option>
              <option value="Bouaké">Site Bouaké</option>
              <option value="Abidjan">Site Abidjan</option>
              <option value="Katiola">Site Katiola</option>
            </select>
            <button
              type="button"
              className="button button-primary"
              onClick={() => window.print()}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
            >
              <Printer size={15} /> Imprimer Planche
            </button>
            <button type="button" className="icon-button" onClick={onClose}>
              <X size={18} />
            </button>
          </div>
        </div>

        <div className="batch-labels-grid printable-area">
          {filteredAssets.map((asset) => {
            const tag = String(asset.asset_tag || asset['Nom Machine'] || asset.id);
            const marque = String(asset.marque || '');
            const modele = String(asset.modele || '');
            const sn = String(asset.serial_number || '');
            const site = String(asset.site || 'Bouaké');
            return (
              <div key={String(asset.id)} className="asset-label-sticker">
                <div style={{ width: 60, height: 60, flexShrink: 0, background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 4, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <img
                    src={`https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${encodeURIComponent(tag)}`}
                    alt={tag}
                    style={{ width: 52, height: 52 }}
                  />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="asset-label-header">DIRECTION IT • {site.toUpperCase()}</div>
                  <div className="asset-label-title" title={tag}>{tag}</div>
                  <div className="asset-label-sub" title={`${marque} ${modele}`}>{marque} {modele}</div>
                  <div className="asset-label-sn">S/N: {sn || 'N/A'}</div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// 3. SIGNATURE TACTILE NUMÉRIQUE (SIGNATURE PAD MODAL)
// ============================================================================
export function SignaturePadModal({
  isOpen,
  onClose,
  title,
  beneficiaire,
  onSave,
}: {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  beneficiaire: string;
  onSave: (signatureDataUrl: string) => Promise<void> | void;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [hasDrawn, setHasDrawn] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    setHasDrawn(false);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.strokeStyle = '#0f172a';
        ctx.lineWidth = 2.5;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
      }
    }
  }, [isOpen]);

  function getPos(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    return {
      x: (e.clientX - rect.left) * scaleX,
      y: (e.clientY - rect.top) * scaleY,
    };
  }

  function handlePointerDown(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const pos = getPos(e);
    ctx.beginPath();
    ctx.moveTo(pos.x, pos.y);
    setIsDrawing(true);
    setHasDrawn(true);
  }

  function handlePointerMove(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!isDrawing) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const pos = getPos(e);
    ctx.lineTo(pos.x, pos.y);
    ctx.stroke();
  }

  function handlePointerUp() {
    setIsDrawing(false);
  }

  function handleClear() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      setHasDrawn(false);
    }
  }

  async function handleSubmit() {
    if (!hasDrawn) {
      alert('Veuillez apposer votre signature avant de valider.');
      return;
    }
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dataUrl = canvas.toDataURL('image/png');
    setIsSubmitting(true);
    try {
      await onSave(dataUrl);
      onClose();
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Erreur lors de la validation');
    } finally {
      setIsSubmitting(false);
    }
  }

  if (!isOpen) return null;

  return (
    <div className="signature-modal-overlay" onClick={onClose}>
      <div className="signature-card" onClick={(e) => e.stopPropagation()}>
        <div className="scanner-header" style={{ background: '#fff', color: '#0f172a', borderBottom: '1px solid #e2e8f0' }}>
          <div>
            <strong style={{ fontSize: 15, display: 'flex', alignItems: 'center', gap: 6 }}>
              <PenTool size={16} color="#0284c7" /> {title}
            </strong>
            <span style={{ fontSize: 11, color: '#64748b' }}>Émargement pour : {beneficiaire}</span>
          </div>
          <button type="button" className="icon-button" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="signature-canvas-wrapper">
          <canvas
            ref={canvasRef}
            width={460}
            height={200}
            className="signature-canvas"
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerUp}
            onPointerLeave={handlePointerUp}
          />
          {!hasDrawn && <div className="signature-watermark">Signez au doigt ou au stylet ici</div>}
        </div>

        <div style={{ padding: '0 20px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <button
            type="button"
            className="button button-secondary"
            onClick={handleClear}
            style={{ fontSize: 12 }}
          >
            <RotateCcw size={13} /> Effacer
          </button>

          <div style={{ display: 'flex', gap: 10 }}>
            <button type="button" className="button button-secondary" onClick={onClose} style={{ fontSize: 12 }}>
              Annuler
            </button>
            <button
              type="button"
              className="button button-primary"
              onClick={() => void handleSubmit()}
              disabled={isSubmitting || !hasDrawn}
              style={{ fontSize: 12, display: 'inline-flex', alignItems: 'center', gap: 6 }}
            >
              <CheckCircle2 size={14} /> {isSubmitting ? 'Génération...' : 'Valider & Télécharger PDF'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// 4. MODULE CAMPAGNE D'INVENTAIRE PHYSIQUE & AUDIT TERRAIN (/audits)
// ============================================================================
export function AuditsPage() {
  const { token } = useAuth();
  const [campagnes, setCampagnes] = useState<Array<Record<string, unknown>>>([]);
  const [selectedCampagneId, setSelectedCampagneId] = useState<number | null>(null);
  const [campagneData, setCampagneData] = useState<Record<string, any> | null>(null);
  const [activeTab, setActiveTab] = useState<'tous' | 'conformes' | 'anomalies' | 'manquants'>('tous');
  const [scanInput, setScanInput] = useState('');
  const [showScanner, setShowScanner] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newTitre, setNewTitre] = useState('');
  const [newSite, setNewSite] = useState('Bouaké');
  const [newNotes, setNewNotes] = useState('');
  const [scanFeedback, setScanFeedback] = useState<{ message: string; type: 'success' | 'warning' | 'error' } | null>(null);

  useEffect(() => {
    loadCampagnes();
  }, [token]);

  async function loadCampagnes() {
    try {
      const list = await apiRequest<Array<Record<string, unknown>>>('/audits', { token });
      setCampagnes(list);
      if (list.length > 0 && !selectedCampagneId) {
        setSelectedCampagneId(Number(list[0].id));
      }
    } catch (_) {}
  }

  useEffect(() => {
    if (selectedCampagneId) {
      loadCampagneDetails(selectedCampagneId);
    }
  }, [selectedCampagneId, token]);

  async function loadCampagneDetails(id: number) {
    try {
      const data = await apiRequest<Record<string, any>>(`/audits/${id}`, { token });
      setCampagneData(data);
    } catch (_) {}
  }

  async function handleCreateCampagne(e: FormEvent) {
    e.preventDefault();
    if (!newTitre.trim()) return;
    try {
      const res = await apiRequest<{ id: number }>('/audits', {
        token,
        method: 'POST',
        body: { titre: newTitre, site: newSite, notes: newNotes }
      });
      setShowCreateModal(false);
      setNewTitre('');
      await loadCampagnes();
      setSelectedCampagneId(res.id);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur création');
    }
  }

  async function handleScanSubmit(codeToScan?: string) {
    const code = (codeToScan || scanInput).trim();
    if (!code || !selectedCampagneId) return;
    const siteConstate = campagneData?.campagne?.site || 'Bouaké';

    if (!navigator.onLine) {
      enqueueOfflineAction({
        type: 'AUDIT_SCAN',
        endpoint: `/audits/${selectedCampagneId}/scan`,
        method: 'POST',
        body: { code, site_constate: siteConstate },
        label: `Scan Audit ${code} (${siteConstate})`,
      });
      setScanInput('');
      setScanFeedback({
        message: `📡 Mode hors-ligne : pointage de "${code}" sauvegardé localement. Il sera synchronisé automatiquement dès le retour du réseau.`,
        type: 'warning',
      });
      return;
    }

    try {
      const res = await apiRequest<any>(`/audits/${selectedCampagneId}/scan`, {
        token,
        method: 'POST',
        body: { code, site_constate: siteConstate }
      });
      setScanInput('');
      setScanFeedback({
        message: res.conforme
          ? `✓ Équipement ${res.asset_tag} validé et conforme sur ${res.site_scanne} !`
          : `⚠️ Anomalie détectée pour ${res.asset_tag} : attendu sur "${res.site_theorique || 'Inconnu'}", scanné sur "${res.site_scanne}".`,
        type: res.conforme ? 'success' : 'warning'
      });
      await loadCampagneDetails(selectedCampagneId);
      await loadCampagnes();
    } catch (err: unknown) {
      const isNetworkError = err instanceof Error && 'status' in err && (err as { status: number }).status === 0;
      if (isNetworkError) {
        enqueueOfflineAction({
          type: 'AUDIT_SCAN',
          endpoint: `/audits/${selectedCampagneId}/scan`,
          method: 'POST',
          body: { code, site_constate: siteConstate },
          label: `Scan Audit ${code} (${siteConstate})`,
        });
        setScanInput('');
        setScanFeedback({
          message: `📡 Réseau inaccessible : pointage de "${code}" mis en file d'attente hors-ligne.`,
          type: 'warning',
        });
        return;
      }
      setScanFeedback({
        message: err instanceof Error ? err.message : 'Erreur lors du scan',
        type: 'error'
      });
    }
  }

  function handleExportCsv() {
    if (!campagneData) return;
    const scans = campagneData.scans || [];
    const manquants = campagneData.manquants || [];
    const rows = [
      ['Campagne', campagneData.campagne.titre],
      ['Site', campagneData.campagne.site],
      ['Statut', campagneData.campagne.statut],
      [],
      ['Type de constat', 'Tag Machine', 'Marque & Modèle', 'Site Théorique', 'Site Constaté', 'Scanné Par', 'Date Scan'],
      ...scans.map((s: any) => [
        s.conforme ? 'CONFORME' : 'ANOMALIE DE SITE',
        s.asset_tag,
        `${s.marque || ''} ${s.modele || ''}`,
        s.site_theorique || 'Non assigné',
        s.site_scanne || '',
        s.scanne_par || '',
        s.scanned_at || ''
      ]),
      ...manquants.map((m: any) => [
        'MANQUANT (NON TROUVÉ)',
        m.asset_tag,
        `${m.marque || ''} ${m.modele || ''}`,
        m.site || '',
        'ABSENT DU POINTAGE',
        '',
        ''
      ])
    ];

    const csvContent = '\uFEFF' + rows.map((e) => e.map((val: unknown) => `"${String(val).replace(/"/g, '""')}"`).join(';')).join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `Audit_Inventaire_${campagneData.campagne.titre.replace(/\s+/g, '_')}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">AUDIT & INVENTAIRE PHYSIQUE</span>
          <h1>Campagnes de Pointage Terrain</h1>
          <p>Contrôle de présence physique des équipements sur les sites et détection des écarts.</p>
        </div>
        <div className="heading-actions">
          <button
            type="button"
            className="button button-primary"
            onClick={() => setShowCreateModal(true)}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <Plus size={15} /> Nouvelle Campagne
          </button>
        </div>
      </div>

      {/* Sélecteur de campagne active */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 20, flexWrap: 'wrap' }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: '#64748b' }}>Campagne active :</span>
        <select
          className="select"
          value={selectedCampagneId || ''}
          onChange={(e) => setSelectedCampagneId(Number(e.target.value))}
          style={{ minWidth: 280, fontWeight: 600 }}
        >
          {campagnes.map((c) => (
            <option key={String(c.id)} value={String(c.id)}>
              {String(c.titre)} • {String(c.site)} ({String(c.progression_pct || 0)}% pointé)
            </option>
          ))}
          {campagnes.length === 0 && <option value="">Aucune campagne enregistrée</option>}
        </select>
        {campagneData && (
          <button
            type="button"
            className="button button-secondary"
            onClick={handleExportCsv}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <FileSpreadsheet size={15} /> Exporter PV d'Audit (CSV)
          </button>
        )}
      </div>

      {campagneData ? (
        <>
          {/* Synthèse et progression */}
          <div className="audit-overview-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 16 }}>
              <div>
                <span style={{ fontSize: 12, letterSpacing: 0.5, color: '#38bdf8', textTransform: 'uppercase', fontWeight: 700 }}>
                  SITE AUDITÉ : {campagneData.campagne.site}
                </span>
                <h2 style={{ margin: '4px 0 8px', fontSize: 22, color: '#fff' }}>{campagneData.campagne.titre}</h2>
                <p style={{ margin: 0, fontSize: 13, color: '#94a3b8' }}>
                  Créée par {campagneData.campagne.created_by} • Statut : <span style={{ color: '#22c55e', fontWeight: 700 }}>{campagneData.campagne.statut === 'en_cours' ? 'EN COURS DE POINTAGE' : 'CLÔTURÉE'}</span>
                </p>
              </div>

              <div style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 32, fontWeight: 900, color: '#38bdf8' }}>{campagneData.stats.progression_pct}%</div>
                  <div style={{ fontSize: 11, color: '#94a3b8' }}>Taux d'avancement</div>
                </div>
              </div>
            </div>

            {/* Barre de progression */}
            <div style={{ marginTop: 20, height: 8, background: 'rgba(255,255,255,0.15)', borderRadius: 4, overflow: 'hidden' }}>
              <div
                style={{
                  height: '100%',
                  width: `${campagneData.stats.progression_pct}%`,
                  background: 'linear-gradient(90deg, #38bdf8, #22c55e)',
                  borderRadius: 4,
                  transition: 'width 0.4s ease'
                }}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: 12, marginTop: 20 }}>
              <div style={{ background: 'rgba(255,255,255,0.06)', padding: 12, borderRadius: 10 }}>
                <div style={{ fontSize: 11, color: '#94a3b8' }}>Attendu sur site</div>
                <div style={{ fontSize: 20, fontWeight: 800 }}>{campagneData.stats.total_attendus}</div>
              </div>
              <div style={{ background: 'rgba(34, 197, 94, 0.15)', padding: 12, borderRadius: 10, border: '1px solid rgba(34, 197, 94, 0.3)' }}>
                <div style={{ fontSize: 11, color: '#86efac' }}>Conformes pointés</div>
                <div style={{ fontSize: 20, fontWeight: 800, color: '#4ade80' }}>{campagneData.stats.conformes}</div>
              </div>
              <div style={{ background: 'rgba(245, 158, 11, 0.15)', padding: 12, borderRadius: 10, border: '1px solid rgba(245, 158, 11, 0.3)' }}>
                <div style={{ fontSize: 11, color: '#fde68a' }}>Anomalies de site</div>
                <div style={{ fontSize: 20, fontWeight: 800, color: '#fbbf24' }}>{campagneData.stats.anomalies}</div>
              </div>
              <div style={{ background: 'rgba(239, 68, 68, 0.15)', padding: 12, borderRadius: 10, border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                <div style={{ fontSize: 11, color: '#fca5a5' }}>Manquants / Non vus</div>
                <div style={{ fontSize: 20, fontWeight: 800, color: '#f87171' }}>{campagneData.stats.manquants}</div>
              </div>
            </div>
          </div>

          {/* Barre de scan terrain rapide */}
          <div className="audit-scan-bar">
            <input
              type="text"
              placeholder="Scanner ou saisir un Tag / Numéro de série..."
              value={scanInput}
              onChange={(e) => setScanInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void handleScanSubmit();
              }}
              style={{ flex: 1, border: 'none', outline: 'none', fontSize: 14, padding: '0 8px' }}
            />
            <button
              type="button"
              className="button button-secondary"
              onClick={() => void handleScanSubmit()}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
            >
              <PackageCheck size={16} /> Pointer
            </button>
            <button
              type="button"
              className="button button-primary"
              onClick={() => setShowScanner(true)}
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
            >
              <ScanLine size={16} /> Scanner Caméra
            </button>
          </div>

          {/* Notification feedback scan */}
          {scanFeedback && (
            <div
              style={{
                padding: '12px 16px',
                borderRadius: 10,
                marginBottom: 16,
                fontSize: 13,
                fontWeight: 600,
                background: scanFeedback.type === 'success' ? '#dcfce7' : scanFeedback.type === 'warning' ? '#fef3c7' : '#fee2e2',
                color: scanFeedback.type === 'success' ? '#166534' : scanFeedback.type === 'warning' ? '#92400e' : '#991b1b',
                border: `1px solid ${scanFeedback.type === 'success' ? '#86efac' : scanFeedback.type === 'warning' ? '#fde68a' : '#fca5a5'}`
              }}
            >
              {scanFeedback.message}
            </div>
          )}

          {/* Onglets des résultats de pointage */}
          <div className="audit-tabs">
            <button
              type="button"
              className={`audit-tab-btn ${activeTab === 'tous' ? 'active' : ''}`}
              onClick={() => setActiveTab('tous')}
            >
              Tous les scans ({campagneData.scans.length})
            </button>
            <button
              type="button"
              className={`audit-tab-btn ${activeTab === 'conformes' ? 'active' : ''}`}
              onClick={() => setActiveTab('conformes')}
            >
              🟢 Conformes ({campagneData.stats.conformes})
            </button>
            <button
              type="button"
              className={`audit-tab-btn ${activeTab === 'anomalies' ? 'active' : ''}`}
              onClick={() => setActiveTab('anomalies')}
            >
              🟡 Anomalies de site ({campagneData.stats.anomalies})
            </button>
            <button
              type="button"
              className={`audit-tab-btn ${activeTab === 'manquants' ? 'active' : ''}`}
              onClick={() => setActiveTab('manquants')}
            >
              🔴 Manquants non pointés ({campagneData.stats.manquants})
            </button>
          </div>

          {/* Table de pointage */}
          <div className="panel" style={{ padding: 0, overflow: 'hidden' }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Statut Constat</th>
                  <th>Équipement / Tag</th>
                  <th>Modèle & Type</th>
                  <th>Site Enregistré</th>
                  <th>Site Constaté</th>
                  <th>Pointé par</th>
                  <th>Date & Heure</th>
                </tr>
              </thead>
              <tbody>
                {activeTab !== 'manquants' &&
                  campagneData.scans
                    .filter((s: any) => {
                      if (activeTab === 'conformes') return s.conforme === 1;
                      if (activeTab === 'anomalies') return s.conforme === 0;
                      return true;
                    })
                    .map((s: any) => (
                      <tr key={String(s.id)}>
                        <td>
                          {s.conforme === 1 ? (
                            <span className="audit-badge conforme">✓ Conforme</span>
                          ) : (
                            <span className="audit-badge anomalie">⚠️ Déplacé / Anomalie</span>
                          )}
                        </td>
                        <td>
                          <strong>{s.asset_tag}</strong>
                        </td>
                        <td>{s.marque} {s.modele} <span style={{ color: '#64748b', fontSize: 11 }}>({s.type})</span></td>
                        <td>{s.site_theorique || 'Non assigné'}</td>
                        <td><strong>{s.site_scanne}</strong></td>
                        <td>{s.scanne_par}</td>
                        <td style={{ fontSize: 11, color: '#64748b' }}>
                          {s.scanned_at ? new Date(s.scanned_at).toLocaleString('fr-FR') : '-'}
                        </td>
                      </tr>
                    ))}

                {activeTab === 'manquants' &&
                  campagneData.manquants.map((m: any) => (
                    <tr key={String(m.id)}>
                      <td>
                        <span className="audit-badge manquant">Non pointé</span>
                      </td>
                      <td><strong>{m.asset_tag}</strong></td>
                      <td>{m.marque} {m.modele} <span style={{ color: '#64748b', fontSize: 11 }}>({m.type})</span></td>
                      <td>{m.site}</td>
                      <td style={{ color: '#ef4444', fontStyle: 'italic' }}>Absent lors du passage</td>
                      <td>-</td>
                      <td>-</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </>
      ) : (
        <div className="panel" style={{ textAlign: 'center', padding: 40 }}>
          <ClipboardCheck size={48} color="#94a3b8" style={{ margin: '0 auto 12px' }} />
          <h3>Aucune campagne d'inventaire sélectionnée</h3>
          <p style={{ color: '#64748b', maxWidth: 400, margin: '0 auto 16px' }}>
            Créez une première campagne d'audit pour commencer le pointage physique des machines sur site.
          </p>
          <button
            type="button"
            className="button button-primary"
            onClick={() => setShowCreateModal(true)}
          >
            Créer une Campagne d'Inventaire
          </button>
        </div>
      )}

      {/* Modal Création de Campagne */}
      {showCreateModal && (
        <div className="dialog-overlay" onClick={() => setShowCreateModal(false)}>
          <div className="create-dialog" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 460 }}>
            <h3>Nouvelle Campagne d'Inventaire</h3>
            <p style={{ color: '#64748b', fontSize: 12 }}>
              Planifiez un pointage physique des machines pour un site spécifique.
            </p>
            <form onSubmit={handleCreateCampagne} style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 16 }}>
              <div>
                <label className="field-label">Titre de la campagne *</label>
                <input
                  type="text"
                  className="input"
                  placeholder="Ex: Inventaire Annuel Bouaké 2026"
                  value={newTitre}
                  onChange={(e) => setNewTitre(e.target.value)}
                  required
                />
              </div>
              <div>
                <label className="field-label">Site géographique cible</label>
                <select className="select" value={newSite} onChange={(e) => setNewSite(e.target.value)}>
                  <option value="Bouaké">Site de Bouaké (Siège)</option>
                  <option value="Abidjan">Site d'Abidjan</option>
                  <option value="Katiola">Site de Katiola</option>
                  <option value="Tous">Tous les sites consolidés</option>
                </select>
              </div>
              <div>
                <label className="field-label">Notes ou instructions terrain</label>
                <textarea
                  className="input"
                  rows={3}
                  placeholder="Instructions pour les techniciens (bâtiments, horaires)..."
                  value={newNotes}
                  onChange={(e) => setNewNotes(e.target.value)}
                />
              </div>
              <div className="dialog-actions">
                <button type="button" className="button button-secondary" onClick={() => setShowCreateModal(false)}>
                  Annuler
                </button>
                <button type="submit" className="button button-primary">
                  Lancer la Campagne
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Scanner Caméra intégré */}
      <QrScannerModal
        isOpen={showScanner}
        onClose={() => setShowScanner(false)}
        onScan={(code) => {
          void handleScanSubmit(code);
        }}
      />
    </div>
  );
}

// ============================================================================
// 5. JOURNAL D'AUDIT & TRAÇABILITÉ SYSTÈME (/logs)
// ============================================================================
export function ActivityLogsPage() {
  const { token } = useAuth();
  const [logs, setLogs] = useState<Array<Record<string, unknown>>>([]);
  const [stats, setStats] = useState<{ total: number; last_24h: number; by_action: Array<{ action: string; count: number }> } | null>(null);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [search, setSearch] = useState('');
  const [entityFilter, setEntityFilter] = useState('');
  const [emailStatus, setEmailStatus] = useState<string>('');
  const [sendingEmail, setSendingEmail] = useState(false);

  async function loadLogs() {
    setLoading(true);
    try {
      const res = await apiRequest<any>('/logs', {
        token,
        query: {
          page,
          limit: 25,
          search: search.trim() || undefined,
          entity_type: entityFilter || undefined,
        },
      });
      if (Array.isArray(res)) {
        setLogs(res);
      } else if (res && Array.isArray(res.data)) {
        setLogs(res.data);
        setTotalPages(res.pagination?.totalPages || 1);
      }
    } catch (_) {
      setLogs([]);
    } finally {
      setLoading(false);
    }
  }

  async function loadStats() {
    try {
      const data = await apiRequest<any>('/logs/stats', { token });
      setStats(data);
    } catch (_) {}
  }

  useEffect(() => {
    void loadLogs();
  }, [token, page, entityFilter]);

  useEffect(() => {
    void loadStats();
  }, [token]);

  async function handleTriggerExpiringDigest() {
    setSendingEmail(true);
    setEmailStatus('');
    try {
      const res = await apiRequest<{ sent: boolean; licences?: number; garanties?: number; recipients?: number }>('/dashboard/send-expiring-alerts', {
        token,
        method: 'POST',
      });
      if (res.sent) {
        setEmailStatus(`✅ Veille échéances envoyée (${res.licences} licence(s), ${res.garanties} garantie(s)) à ${res.recipients} admin(s).`);
      } else {
        setEmailStatus('ℹ️ Aucune licence ou garantie n’arrive à échéance dans les 30 prochains jours.');
      }
    } catch (err: unknown) {
      setEmailStatus(err instanceof Error ? `❌ ${err.message}` : '❌ Erreur lors de l’envoi.');
    } finally {
      setSendingEmail(false);
    }
  }

  function handleExportLogsCsv() {
    const headers = ['ID', 'Date/Heure', 'Auteur', 'Rôle', 'Action', 'Entité', 'ID Entité', 'Détails', 'Adresse IP'];
    const rows = logs.map((l) => [
      l.id,
      l.created_at ? new Date(String(l.created_at)).toLocaleString('fr-FR') : '',
      [l.prenom, l.nom].filter(Boolean).join(' ') || l.username || `User #${l.user_id || '?'}`,
      l.role || '',
      l.action,
      l.entity_type || '',
      l.entity_id || '',
      typeof l.details === 'object' && l.details ? JSON.stringify(l.details) : String(l.details || ''),
      l.ip_address || '',
    ]);
    const csv = '\uFEFF' + [headers.join(';'), ...rows.map((r) => r.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(';'))].join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `Journal_Audit_ParcIT_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function actionBadgeStyle(action: string): { bg: string; color: string } {
    const a = (action || '').toUpperCase();
    if (a.includes('DELETE') || a.includes('REMOVE')) return { bg: '#fee2e2', color: '#991b1b' };
    if (a.includes('CREATE') || a.includes('ADD')) return { bg: '#dcfce7', color: '#166534' };
    if (a.includes('RESTITUTION') || a.includes('RETRAIT')) return { bg: '#fef3c7', color: '#92400e' };
    if (a.includes('LOGIN')) return { bg: '#ede9fe', color: '#5b21b6' };
    return { bg: '#e0f2fe', color: '#075985' };
  }

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">SÉCURITÉ & GOUVERNANCE</span>
          <h1>Journal d'Audit Système</h1>
          <p>Traçabilité complète des opérations critiques, connexions et alertes automatiques.</p>
        </div>
        <div className="heading-actions">
          <button
            type="button"
            className="button button-primary"
            onClick={() => void handleTriggerExpiringDigest()}
            disabled={sendingEmail}
            title="Envoyer par e-mail le rapport des licences et garanties expirant sous 30 jours"
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <Mail size={15} /> {sendingEmail ? 'Envoi...' : 'Veille Échéances (E-mail)'}
          </button>
          <button
            type="button"
            className="button button-secondary"
            onClick={handleExportLogsCsv}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <FileSpreadsheet size={15} /> Exporter CSV
          </button>
          <button
            type="button"
            className="button button-secondary"
            onClick={() => { void loadLogs(); void loadStats(); }}
          >
            <RefreshCw size={15} /> Actualiser
          </button>
        </div>
      </div>

      {emailStatus && (
        <div className="panel" style={{ padding: '12px 16px', marginBottom: 16, fontSize: 13, fontWeight: 600, background: '#f0f9ff', borderColor: '#bae6fd', color: '#0369a1' }}>
          {emailStatus}
        </div>
      )}

      {stats && (
        <div className="finance-kpi-grid" style={{ marginBottom: 20 }}>
          <div className="finance-card">
            <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Événements Tracés</span>
            <div className="finance-amount" style={{ color: '#0284c7' }}>{Number(stats.total).toLocaleString('fr-FR')}</div>
            <span style={{ fontSize: 11, color: '#64748b' }}>Historique total enregistré</span>
          </div>
          <div className="finance-card">
            <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Activité (24h)</span>
            <div className="finance-amount" style={{ color: '#16a34a' }}>{Number(stats.last_24h).toLocaleString('fr-FR')}</div>
            <span style={{ fontSize: 11, color: '#64748b' }}>Opérations récentes</span>
          </div>
          <div className="finance-card">
            <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Action la plus fréquente</span>
            <div className="finance-amount" style={{ fontSize: 16, color: '#7c3aed' }}>
              {stats.by_action?.[0]?.action || '—'}
            </div>
            <span style={{ fontSize: 11, color: '#64748b' }}>
              {stats.by_action?.[0]?.count ? `${stats.by_action[0].count} occurrences` : 'Aucune donnée'}
            </span>
          </div>
        </div>
      )}

      <section className="panel data-panel">
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 16, alignItems: 'center' }}>
          <form
            onSubmit={(e) => { e.preventDefault(); setPage(1); void loadLogs(); }}
            style={{ display: 'flex', gap: 8, flex: 1, minWidth: 240 }}
          >
            <div style={{ position: 'relative', flex: 1 }}>
              <Search size={15} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                className="input"
                placeholder="Rechercher par action, utilisateur, détails..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{ paddingLeft: 32, width: '100%' }}
              />
            </div>
            <button type="submit" className="button button-secondary">Filtrer</button>
          </form>

          <select
            className="select"
            value={entityFilter}
            onChange={(e) => { setEntityFilter(e.target.value); setPage(1); }}
            style={{ minWidth: 180 }}
          >
            <option value="">Toutes les entités</option>
            <option value="asset">Équipements (asset)</option>
            <option value="affectation">Affectations</option>
            <option value="ticket">Tickets IT</option>
            <option value="user">Utilisateurs</option>
            <option value="licence">Licences</option>
            <option value="consommable">Consommables</option>
          </select>
        </div>

        {loading ? (
          <div className="loading-lines"><i /><i /><i /></div>
        ) : (
          <div className="table-scroll">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Date & Heure</th>
                  <th>Auteur</th>
                  <th>Action</th>
                  <th>Cible</th>
                  <th>Détails</th>
                  <th>IP</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => {
                  const badge = actionBadgeStyle(String(log.action || ''));
                  const author = [log.prenom, log.nom].filter(Boolean).join(' ') || String(log.username || (log.user_id ? `Compte #${log.user_id}` : 'Système'));
                  const detailsStr = typeof log.details === 'object' && log.details ? JSON.stringify(log.details) : String(log.details || '—');
                  return (
                    <tr key={String(log.id)}>
                      <td style={{ whiteSpace: 'nowrap', fontSize: 11, color: '#64748b' }}>
                        <Clock size={12} style={{ verticalAlign: 'middle', marginRight: 4 }} />
                        {log.created_at ? new Date(String(log.created_at)).toLocaleString('fr-FR') : '—'}
                      </td>
                      <td>
                        <strong>{author}</strong>
                        {Boolean(log.role) && (
                          <span style={{ marginLeft: 6, fontSize: 10, padding: '1px 6px', borderRadius: 6, background: '#f1f5f9', color: '#475569' }}>
                            {String(log.role)}
                          </span>
                        )}
                      </td>
                      <td>
                        <span style={{ padding: '3px 8px', borderRadius: 8, fontSize: 11, fontWeight: 700, background: badge.bg, color: badge.color }}>
                          {String(log.action)}
                        </span>
                      </td>
                      <td style={{ fontSize: 12 }}>
                        {log.entity_type ? `${String(log.entity_type)} #${String(log.entity_id || '')}` : '—'}
                      </td>
                      <td style={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', fontSize: 11, fontFamily: 'ui-monospace, monospace', color: '#475569' }} title={detailsStr}>
                        {detailsStr}
                      </td>
                      <td style={{ fontSize: 11, color: '#94a3b8' }}>{String(log.ip_address || '—')}</td>
                    </tr>
                  );
                })}
                {!logs.length && (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: 32, color: '#94a3b8' }}>
                      <ShieldAlert size={28} style={{ display: 'block', margin: '0 auto 8px', opacity: 0.5 }} />
                      Aucun événement enregistré pour ces critères.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16 }}>
          <span style={{ fontSize: 12, color: '#64748b' }}>Page {page} / {totalPages}</span>
          <div style={{ display: 'flex', gap: 8 }}>
            <button type="button" className="button button-secondary" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
              Précédent
            </button>
            <button type="button" className="button button-secondary" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              Suivant
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}

// ============================================================================
// 6. PORTAIL COLLABORATEUR ("MON ESPACE IT & MES ÉQUIPEMENTS") (/mes-equipements)
// ============================================================================
export function MonEspacePage() {
  const { token, user } = useAuth();
  const [equipements, setEquipements] = useState<Array<Record<string, unknown>>>([]);
  const [tickets, setTickets] = useState<Array<Record<string, unknown>>>([]);
  const [loading, setLoading] = useState(true);
  const [incidentAsset, setIncidentAsset] = useState<Record<string, unknown> | null>(null);
  const [titre, setTitre] = useState('');
  const [description, setDescription] = useState('');
  const [priorite, setPriorite] = useState('moyenne');
  const [submitting, setSubmitting] = useState(false);
  const [feedback, setFeedback] = useState('');

  async function loadMonEspace() {
    setLoading(true);
    try {
      const res = await apiRequest<{ equipements: Array<Record<string, unknown>>; tickets: Array<Record<string, unknown>> }>('/dashboard/mon-espace', { token });
      setEquipements(res.equipements || []);
      setTickets(res.tickets || []);
    } catch (_) {
      setEquipements([]);
      setTickets([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadMonEspace();
  }, [token]);

  async function handleDownloadDecharge(affId: number, tag: string) {
    try {
      const blob = await apiDownload(`/affectations/${affId}/pdf`, { token });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Decharge_${tag || affId}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur téléchargement');
    }
  }

  async function handleSubmitIncident(e: FormEvent) {
    e.preventDefault();
    if (!titre.trim() || !description.trim()) return;
    setSubmitting(true);
    const payload = {
      asset_id: incidentAsset ? Number(incidentAsset.asset_id) : null,
      titre: titre.trim(),
      description: description.trim(),
      priorite,
    };

    if (!navigator.onLine) {
      enqueueOfflineAction({
        type: 'INCIDENT_REPORT',
        endpoint: '/dashboard/mon-espace/incident',
        method: 'POST',
        body: payload,
        label: `Incident : ${titre.trim()}`,
      });
      setIncidentAsset(null);
      setTitre('');
      setDescription('');
      setSubmitting(false);
      setFeedback('📡 Hors-ligne : votre signalement a été enregistré localement et sera envoyé dès le retour du réseau.');
      return;
    }

    try {
      const res = await apiRequest<{ numero: string }>('/dashboard/mon-espace/incident', {
        token,
        method: 'POST',
        body: payload,
      });
      setIncidentAsset(null);
      setTitre('');
      setDescription('');
      setFeedback(`✅ Ticket ${res.numero} créé et transmis à l'équipe IT !`);
      await loadMonEspace();
    } catch (err: unknown) {
      const isNetworkError = err instanceof Error && 'status' in err && (err as { status: number }).status === 0;
      if (isNetworkError) {
        enqueueOfflineAction({
          type: 'INCIDENT_REPORT',
          endpoint: '/dashboard/mon-espace/incident',
          method: 'POST',
          body: payload,
          label: `Incident : ${titre.trim()}`,
        });
        setIncidentAsset(null);
        setTitre('');
        setDescription('');
        setFeedback('📡 Réseau indisponible : signalement mis en file d’attente hors-ligne.');
      } else {
        alert(err instanceof Error ? err.message : 'Erreur lors de l’envoi');
      }
    } finally {
      setSubmitting(false);
    }
  }

  const displayName = [user?.prenom, user?.nom].filter(Boolean).join(' ') || user?.username || 'Collaborateur';

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">PORTAIL COLLABORATEUR</span>
          <h1>Mon Espace IT & Mes Équipements</h1>
          <p>Bienvenue <strong>{displayName}</strong> — consultez vos matériels attribués et signalez un incident en 1 clic.</p>
        </div>
        <div className="heading-actions">
          <button
            type="button"
            className="button button-primary"
            onClick={() => {
              setIncidentAsset(equipements[0] || {});
              setTitre('');
              setDescription('');
            }}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          >
            <AlertTriangle size={15} /> Signaler un problème
          </button>
          <button
            type="button"
            className="button button-secondary"
            onClick={() => void loadMonEspace()}
          >
            <RefreshCw size={15} /> Actualiser
          </button>
        </div>
      </div>

      {feedback && (
        <div className="panel" style={{ padding: '12px 16px', marginBottom: 18, background: '#f0fdf4', borderColor: '#bbf7d0', color: '#166534', fontWeight: 600, fontSize: 13 }}>
          {feedback}
        </div>
      )}

      {/* Mes Équipements */}
      <section className="panel pro-card" style={{ marginBottom: 20 }}>
        <div className="panel-heading">
          <div>
            <h2 style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
              <UserCheck size={18} color="#2563eb" /> Matériel attribué à votre nom ({equipements.length})
            </h2>
            <p style={{ fontSize: 11 }}>Équipements informatiques actuellement sous votre responsabilité</p>
          </div>
        </div>

        {loading ? (
          <div className="loading-lines"><i /><i /></div>
        ) : equipements.length > 0 ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(290px, 1fr))', gap: 16, marginTop: 16 }}>
            {equipements.map((eq) => {
              const tag = String(eq.asset_tag || `#${eq.asset_id}`);
              return (
                <div key={String(eq.affectation_id)} className="finance-card" style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div className="pro-icon-box blue"><Laptop size={18} /></div>
                      <div>
                        <strong style={{ fontSize: 15, display: 'block' }}>{tag}</strong>
                        <span style={{ fontSize: 12, color: '#64748b' }}>
                          {[eq.marque, eq.modele].filter(Boolean).join(' ') || String(eq.type || 'Équipement')}
                        </span>
                      </div>
                    </div>
                    <span className="audit-badge conforme">Attribué</span>
                  </div>

                  <div className="mon-espace-specs">
                    <div><span style={{ color: '#94a3b8' }}>S/N :</span> <code>{String(eq.serial_number || 'N/A')}</code></div>
                    <div><span style={{ color: '#94a3b8' }}>Site :</span> {String(eq.site || '—')}</div>
                    <div><span style={{ color: '#94a3b8' }}>OS :</span> {String(eq.os || '—')}</div>
                    <div><span style={{ color: '#94a3b8' }}>Depuis :</span> {eq.date_attribution ? new Date(String(eq.date_attribution)).toLocaleDateString('fr-FR') : '—'}</div>
                  </div>

                  <div style={{ display: 'flex', gap: 8, marginTop: 'auto', paddingTop: 4 }}>
                    <button
                      type="button"
                      className="button button-secondary"
                      style={{ flex: 1, fontSize: 11, padding: '6px 10px', color: '#dc2626', borderColor: '#fecaca', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 5 }}
                      onClick={() => {
                        setIncidentAsset(eq);
                        setTitre(`Incident sur ${tag}`);
                        setDescription('');
                      }}
                    >
                      <AlertTriangle size={13} /> Signaler panne
                    </button>
                    <button
                      type="button"
                      className="button button-secondary"
                      style={{ fontSize: 11, padding: '6px 10px', display: 'inline-flex', alignItems: 'center', gap: 5 }}
                      onClick={() => void handleDownloadDecharge(Number(eq.affectation_id), tag)}
                      title="Télécharger votre fiche de décharge PDF"
                    >
                      <Download size={13} /> Décharge
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div style={{ padding: 28, textAlign: 'center', color: '#64748b', fontSize: 13 }}>
            Aucun équipement n'est actuellement affecté à votre fiche collaborateur ({user?.email || displayName}).
          </div>
        )}
      </section>

      {/* Mes Tickets Récents */}
      <section className="panel pro-card">
        <div className="panel-heading">
          <div>
            <h2 style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
              <Ticket size={18} color="#f59e0b" /> Suivi de mes demandes & incidents ({tickets.length})
            </h2>
            <p style={{ fontSize: 11 }}>Historique de vos signalements auprès du support IT</p>
          </div>
        </div>
        <div className="table-scroll" style={{ marginTop: 14 }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Numéro</th>
                <th>Objet</th>
                <th>Machine</th>
                <th>Priorité</th>
                <th>Statut</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={String(t.id)}>
                  <td><strong>{String(t.numero)}</strong></td>
                  <td>{String(t.titre)}</td>
                  <td>{t.asset_tag ? String(t.asset_tag) : '—'}</td>
                  <td><span className="audit-badge anomalie">{String(t.priorite)}</span></td>
                  <td><span className="audit-badge conforme">{String(t.statut)}</span></td>
                  <td style={{ fontSize: 11, color: '#64748b' }}>
                    {t.created_at ? new Date(String(t.created_at)).toLocaleDateString('fr-FR') : '—'}
                  </td>
                </tr>
              ))}
              {!tickets.length && (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: 24, color: '#94a3b8' }}>
                    Vous n'avez aucun ticket ouvert actuellement.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* Modal Signalement Rapide */}
      {incidentAsset && (
        <div className="dialog-overlay" onClick={() => setIncidentAsset(null)}>
          <div className="create-dialog" style={{ maxWidth: 480 }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h3 style={{ margin: 0 }}>Signaler un incident IT</h3>
              <button type="button" className="icon-button" onClick={() => setIncidentAsset(null)}><X size={18} /></button>
            </div>

            {Boolean(incidentAsset.asset_tag) && (
              <div style={{ padding: '8px 12px', borderRadius: 8, background: '#f1f5f9', fontSize: 12, marginBottom: 12 }}>
                Machine concernée : <strong>{String(incidentAsset.asset_tag)}</strong> ({String(incidentAsset.marque || '')} {String(incidentAsset.modele || '')})
              </div>
            )}

            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
              {['Ne démarre plus / Écran noir', 'Problème Wi-Fi / Réseau', 'Lenteur système', 'Batterie / Chargeur HS'].map((preset) => (
                <button
                  key={preset}
                  type="button"
                  className="filter-pill"
                  style={{ fontSize: 11 }}
                  onClick={() => setTitre(incidentAsset.asset_tag ? `${preset} (${String(incidentAsset.asset_tag)})` : preset)}
                >
                  {preset}
                </button>
              ))}
            </div>

            <form onSubmit={handleSubmitIncident} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div>
                <label className="field-label">Objet de l'incident *</label>
                <input
                  type="text"
                  className="input"
                  required
                  placeholder="Ex: Écran bleu au démarrage"
                  value={titre}
                  onChange={(e) => setTitre(e.target.value)}
                />
              </div>
              <div>
                <label className="field-label">Urgence</label>
                <select className="select" value={priorite} onChange={(e) => setPriorite(e.target.value)}>
                  <option value="basse">Basse (Gêne mineure)</option>
                  <option value="moyenne">Moyenne (Normale)</option>
                  <option value="haute">Haute (Bloquant partiel)</option>
                  <option value="critique">Critique (Arrêt total de travail)</option>
                </select>
              </div>
              <div>
                <label className="field-label">Description détaillée *</label>
                <textarea
                  className="input"
                  rows={3}
                  required
                  placeholder="Décrivez brièvement le symptôme constaté..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>
              <div className="dialog-actions">
                <button type="button" className="button button-secondary" onClick={() => setIncidentAsset(null)}>Annuler</button>
                <button type="submit" className="button button-primary" disabled={submitting}>
                  {submitting ? 'Envoi...' : 'Envoyer au Support IT'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

// ============================================================================
// 7. CENTRE DE PARAMÈTRES & CONFIGURATION DSI (/settings)
// ============================================================================
export function SettingsPage() {
  const { token, user } = useAuth();
  const isAdmin = (user?.role ?? '').toLowerCase() === 'admin';
  const [settings, setSettings] = useState<Record<string, string>>({
    organisation_nom: 'Direction IT Bouaké',
    devise: 'XOF',
    amortissement_mois: '36',
    alerte_licences_jours: '30',
    alerte_garanties_jours: '60',
    email_notifications_auto: 'true',
  });
  const [smtpInfo, setSmtpInfo] = useState<{ enabled: boolean; host: string }>({ enabled: false, host: '' });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testEmail, setTestEmail] = useState(user?.email || '');
  const [testingEmail, setTestingEmail] = useState(false);
  const [feedback, setFeedback] = useState('');

  useEffect(() => {
    apiRequest<{ settings: Record<string, string>; smtp_enabled: boolean; smtp_host: string }>('/settings', { token })
      .then((res) => {
        if (res.settings) setSettings(res.settings);
        setSmtpInfo({ enabled: Boolean(res.smtp_enabled), host: res.smtp_host || 'Mode Simulation' });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [token]);

  async function handleSave(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFeedback('');
    try {
      await apiRequest('/settings', {
        token,
        method: 'PUT',
        body: { settings },
      });
      setFeedback('✅ Paramètres système enregistrés avec succès.');
    } catch (err: unknown) {
      setFeedback(err instanceof Error ? `❌ ${err.message}` : '❌ Erreur lors de la sauvegarde.');
    } finally {
      setSaving(false);
    }
  }

  async function handleTestEmail(e: FormEvent) {
    e.preventDefault();
    if (!testEmail.trim()) return;
    setTestingEmail(true);
    setFeedback('');
    try {
      const res = await apiRequest<{ mode: string; to: string }>('/settings/test-email', {
        token,
        method: 'POST',
        body: { email: testEmail.trim() },
      });
      setFeedback(`📧 Test e-mail exécuté (${res.mode}) vers ${res.to}.`);
    } catch (err: unknown) {
      setFeedback(err instanceof Error ? `❌ ${err.message}` : '❌ Échec du test e-mail.');
    } finally {
      setTestingEmail(false);
    }
  }

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ADMINISTRATION DSI</span>
          <h1>Paramètres & Configuration Système</h1>
          <p>Règles d'amortissement comptable, seuils d'alertes et passerelle e-mail SMTP.</p>
        </div>
      </div>

      {feedback && (
        <div className="panel" style={{ padding: '12px 16px', marginBottom: 18, background: '#f0f9ff', borderColor: '#bae6fd', color: '#0369a1', fontWeight: 600, fontSize: 13 }}>
          {feedback}
        </div>
      )}

      {loading ? (
        <div className="loading-lines"><i /><i /></div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 20 }}>
          <section className="panel pro-card">
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Settings size={18} color="#2563eb" /> Règles Métier & Seuils
                </h2>
                <p style={{ fontSize: 11 }}>Paramètres globaux appliqués au parc informatique</p>
              </div>
            </div>
            <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 16 }}>
              <div>
                <label className="field-label">Nom de l'entité / Direction</label>
                <input
                  type="text"
                  className="input"
                  disabled={!isAdmin}
                  value={settings.organisation_nom || ''}
                  onChange={(e) => setSettings((s) => ({ ...s, organisation_nom: e.target.value }))}
                />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label className="field-label">Durée d'amortissement (mois)</label>
                  <select
                    className="select"
                    disabled={!isAdmin}
                    value={settings.amortissement_mois || '36'}
                    onChange={(e) => setSettings((s) => ({ ...s, amortissement_mois: e.target.value }))}
                  >
                    <option value="24">24 mois (2 ans)</option>
                    <option value="36">36 mois (3 ans)</option>
                    <option value="48">48 mois (4 ans)</option>
                    <option value="60">60 mois (5 ans)</option>
                  </select>
                </div>
                <div>
                  <label className="field-label">Devise comptable</label>
                  <select
                    className="select"
                    disabled={!isAdmin}
                    value={settings.devise || 'XOF'}
                    onChange={(e) => setSettings((s) => ({ ...s, devise: e.target.value }))}
                  >
                    <option value="XOF">XOF (FCFA)</option>
                    <option value="EUR">EUR (€)</option>
                    <option value="USD">USD ($)</option>
                  </select>
                </div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label className="field-label">Alerte Licences (jours avant)</label>
                  <input
                    type="number"
                    className="input"
                    disabled={!isAdmin}
                    min={7}
                    max={180}
                    value={settings.alerte_licences_jours || '30'}
                    onChange={(e) => setSettings((s) => ({ ...s, alerte_licences_jours: e.target.value }))}
                  />
                </div>
                <div>
                  <label className="field-label">Alerte Garanties (jours avant)</label>
                  <input
                    type="number"
                    className="input"
                    disabled={!isAdmin}
                    min={7}
                    max={180}
                    value={settings.alerte_garanties_jours || '60'}
                    onChange={(e) => setSettings((s) => ({ ...s, alerte_garanties_jours: e.target.value }))}
                  />
                </div>
              </div>
              {isAdmin && (
                <button type="submit" className="button button-primary" disabled={saving} style={{ alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  <Save size={15} /> {saving ? 'Enregistrement...' : 'Enregistrer les paramètres'}
                </button>
              )}
            </form>
          </section>

          <section className="panel pro-card">
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Mail size={18} color="#16a34a" /> Passerelle E-mail & Test SMTP
                </h2>
                <p style={{ fontSize: 11 }}>État actuel du serveur d'envoi de notifications</p>
              </div>
            </div>
            <div style={{ marginTop: 16, padding: 14, borderRadius: 10, background: smtpInfo.enabled ? '#f0fdf4' : '#fffbeb', border: `1px solid ${smtpInfo.enabled ? '#bbf7d0' : '#fde68a'}` }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: smtpInfo.enabled ? '#166534' : '#92400e' }}>
                {smtpInfo.enabled ? '🟢 SMTP Actif (Production)' : '🟡 Mode Simulation (Logs Console)'}
              </div>
              <div style={{ fontSize: 12, color: '#475569', marginTop: 4 }}>
                Hôte SMTP : <code>{smtpInfo.host}</code>
              </div>
            </div>
            <form onSubmit={handleTestEmail} style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 18 }}>
              <div>
                <label className="field-label">Envoyer un e-mail de vérification à :</label>
                <input
                  type="email"
                  className="input"
                  required
                  placeholder="admin@entreprise.ci"
                  value={testEmail}
                  onChange={(e) => setTestEmail(e.target.value)}
                />
              </div>
              <button type="submit" className="button button-secondary" disabled={!isAdmin || testingEmail} style={{ alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <Mail size={15} /> {testingEmail ? 'Envoi en cours...' : 'Tester l’envoi E-mail'}
              </button>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}
