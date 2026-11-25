import { useEffect, useMemo, useState, type FormEvent } from 'react';
import {
  Activity,
  Archive,
  ArrowDownToLine,
  ArrowLeftRight,
  Bell,
  BookOpen,
  Boxes,
  BriefcaseBusiness,
  ChartNoAxesCombined,
  ChevronDown,
  CircleAlert,
  CircleHelp,
  ArrowRight,
  Download,
  FileUp,
  HardDrive,
  Laptop,
  LayoutDashboard,
  LifeBuoy,
  LogOut,
  Menu,
  Package,
  Plus,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  Ticket,
  Users,
  X,
  Sun,
  Moon,
  Eye,
  ArrowUpDown,
  Building2,
  PieChart,
  Pencil,
  Trash2,
  QrCode,
  Printer,
  RotateCcw,
  FileSpreadsheet,
  History,
  AlertTriangle,
  Monitor,
  Smartphone,
  Tv,
  CreditCard,
  Server,
  Tablet,
  MapPin,
  Lock,
  Shield,
  ScanLine,
  PenTool,
  Coins,
  ClipboardCheck,
  ShieldAlert,
  UserCheck,
  type LucideIcon,
} from 'lucide-react';
import { Link, Navigate, NavLink, Route, Routes, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { apiDownload, apiRequest } from './api';
import { useAuth } from './auth';
import { QrScannerModal, BatchQrLabelsModal, SignaturePadModal, AuditsPage, ActivityLogsPage, MonEspacePage } from './AuditAndTools';
import { getOfflineQueue, syncOfflineQueue, OFFLINE_QUEUE_EVENT } from './offlineQueue';

type DashboardData = {
  totaux?: Record<string, number>;
  par_type?: Array<{ type: string; count: number }>;
  par_site?: Array<{ site: string; count: number }>;
  par_departement?: Array<{ departement: string; count: number }>;
  securite?: {
    score_conformite?: number;
    total_avec_securite?: number;
    defender_ok?: number;
    bitlocker_ok?: number;
    intune_ok?: number;
  };
  machines_win10?: number;
  non_conformes?: number;
  licences_expirant_bientot?: number;
  stock_critique?: number;
  maintenances_planifiees?: number;
  tickets_urgents?: number;
  alertes_garanties?: Array<{
    id: number;
    asset_tag: string;
    marque: string;
    modele?: string;
    type: string;
    site?: string;
    jours_restants: number;
  }>;
  recents?: Array<{
    id: number;
    asset_tag?: string;
    nom_machine?: string;
    marque?: string;
    modele?: string;
    type?: string;
    site?: string;
    statut?: string;
  }>;
};

function exportToCsv(filename: string, columns: Array<{ key: string; label: string }>, rows: Array<Record<string, unknown>>) {
  const header = columns.map((c) => `"${c.label.replace(/"/g, '""')}"`).join(';');
  const lines = rows.map((r) => {
    return columns.map((c) => {
      const val = getPath(r, c.key);
      const text = cellText(val);
      return `"${text.replace(/"/g, '""')}"`;
    }).join(';');
  });
  const csvContent = '\uFEFF' + [header, ...lines].join('\r\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  URL.revokeObjectURL(url);
  a.remove();
}

type NavigationItem = {
  label: string;
  path: string;
  icon: LucideIcon;
};

type ModuleDefinition = {
  title: string;
  subtitle: string;
  endpoint: string;
  columns: Array<{ key: string; label: string }>;
  canSearch?: boolean;
  paginated?: boolean;
  createFields?: FormFieldDefinition[];
  adminOnlyCreate?: boolean;
  editFields?: FormFieldDefinition[];
  adminOnlyDelete?: boolean;
  wrapAsset?: boolean;
};

type FormFieldDefinition = {
  name: string;
  label: string;
  type?: 'text' | 'email' | 'password' | 'number' | 'date' | 'textarea' | 'select' | 'checkbox';
  required?: boolean;
  options?: string[];
  placeholder?: string;
};

const modules: Record<string, ModuleDefinition> = {
  '/assets': {
    title: 'Inventaire du parc',
    subtitle: 'Équipements informatiques',
    endpoint: '/assets',
    canSearch: true,
    paginated: true,
    wrapAsset: true,
    createFields: [
      { name: 'asset_tag', label: 'Référence d’inventaire (ex: BKE-LT-016)', required: true },
      { name: 'type', label: 'Type d’équipement', type: 'select', options: ['laptop', 'desktop', 'serveur', 'ecran', 'imprimante', 'tablette', 'smartphone', 'reseau'], required: true },
      { name: 'marque', label: 'Marque', required: true, placeholder: 'Dell, HP, Lenovo, Apple…' },
      { name: 'modele', label: 'Modèle', placeholder: 'Latitude 5540, EliteBook…' },
      { name: 'site', label: 'Site', type: 'select', options: ['Bouaké', 'Abidjan', 'Yamoussoukro', 'Katiola', 'Azaguié', 'Djeboa'] },
      { name: 'departement', label: 'Département', type: 'select', options: ['Direction IT', 'Comptabilité', 'Commercial', 'RH', 'Logistique', 'Direction Générale'] },
      { name: 'statut', label: 'Statut initial', type: 'select', options: ['en_service', 'en_stock', 'en_maintenance', 'hors_service', 'reforme'] },
      { name: 'notes', label: 'Notes ou observations', type: 'textarea' },
    ],
    editFields: [
      { name: 'asset_tag', label: 'Référence d’inventaire', required: true },
      { name: 'type', label: 'Type d’équipement', type: 'select', options: ['laptop', 'desktop', 'serveur', 'ecran', 'imprimante', 'tablette', 'smartphone', 'reseau'], required: true },
      { name: 'marque', label: 'Marque', required: true },
      { name: 'modele', label: 'Modèle' },
      { name: 'site', label: 'Site', type: 'select', options: ['Bouaké', 'Abidjan', 'Yamoussoukro', 'Katiola', 'Azaguié', 'Djeboa'] },
      { name: 'departement', label: 'Département', type: 'select', options: ['Direction IT', 'Comptabilité', 'Commercial', 'RH', 'Logistique', 'Direction Générale'] },
      { name: 'statut', label: 'Statut', type: 'select', options: ['en_service', 'en_stock', 'en_maintenance', 'hors_service', 'reforme'] },
      { name: 'notes', label: 'Notes ou observations', type: 'textarea' },
    ],
    adminOnlyDelete: true,
    columns: [
      { key: 'asset_tag', label: 'Référence' }, { key: 'type', label: 'Type' },
      { key: 'marque', label: 'Marque' }, { key: 'modele', label: 'Modèle' },
      { key: 'site', label: 'Site' }, { key: 'statut', label: 'État' },
    ],
  },
  '/affectations': {
    title: 'Affectations', subtitle: 'Attribution et décharge de matériel', endpoint: '/affectations',
    paginated: true,
    columns: [
      { key: 'asset.asset_tag', label: 'Nom Machine' },
      { key: 'user.nom', label: 'Nom Utilisateur' },
      { key: 'user.prenom', label: 'Prénom' },
      { key: 'user.departement', label: 'Département' },
      { key: 'user.site', label: 'Site / Localisation' },
      { key: 'date_attribution', label: 'Date d’attribution' },
      { key: 'date_retrait', label: 'Date de retrait' },
      { key: 'actif', label: 'Statut' },
    ],
    createFields: [
      { name: 'asset_id', label: 'ID ou Référence Équipement', type: 'number', required: true, placeholder: 'Ex: 1' },
      { name: 'nom', label: 'Nom Utilisateur Actuel', required: true, placeholder: 'Ex: OUATTARA' },
      { name: 'prenom', label: 'Prénom Utilisateur', required: true, placeholder: 'Ex: MIGNINIBIN MARCEL' },
      { name: 'departement', label: 'Département', type: 'select', options: ['Direction IT', 'CAJOOMA', 'COMPTABILITE', 'Commercial', 'RH', 'Logistique', 'Direction Générale'] },
      { name: 'site', label: 'Site / Localisation', type: 'select', options: ['BOUAKE', 'ABIDJAN', 'BOUAFLE', 'KATIOLA', 'AZAGUIE', 'DJEBOA', 'YAMOUSSOUKRO'] },
      { name: 'date_attribution', label: 'Date d’attribution', type: 'date', required: true },
      { name: 'ancien_utilisateur', label: 'Ancien Utilisateur (si réattribution)', placeholder: 'Nom et prénom' },
      { name: 'motif', label: 'Motif / Bon de commande / Notes', type: 'textarea', placeholder: 'N° Bon de commande, motif d\'attribution…' },
    ],
    editFields: [
      { name: 'nom', label: 'Nom utilisateur', required: true },
      { name: 'prenom', label: 'Prénom utilisateur', required: true },
      { name: 'departement', label: 'Département', type: 'select', options: ['Direction IT', 'CAJOOMA', 'COMPTABILITE', 'Commercial', 'RH', 'Logistique', 'Direction Générale'] },
      { name: 'site', label: 'Site / Localisation', type: 'select', options: ['BOUAKE', 'ABIDJAN', 'BOUAFLE', 'KATIOLA', 'AZAGUIE', 'DJEBOA', 'YAMOUSSOUKRO'] },
      { name: 'date_attribution', label: 'Date d’attribution', type: 'date', required: true },
      { name: 'date_retrait', label: 'Date de retrait', type: 'date' },
      { name: 'motif', label: 'Motif / Notes', type: 'textarea' },
      { name: 'actif', label: 'Affectation active', type: 'checkbox' },
    ],
  },
  '/tickets': {
    title: 'Tickets IT', subtitle: 'Demandes et incidents', endpoint: '/tickets', canSearch: true,
    paginated: true,
    columns: [
      { key: 'numero', label: 'Numéro' }, { key: 'titre', label: 'Sujet' },
      { key: 'type', label: 'Type' }, { key: 'priorite', label: 'Priorité' },
      { key: 'statut', label: 'État' }, { key: 'created_at', label: 'Créé le' },
    ],
    createFields: [
      { name: 'titre', label: 'Sujet du ticket', required: true, placeholder: 'Ex: Problème d\'écran, mot de passe…' },
      { name: 'type', label: 'Type de ticket', type: 'select', options: ['incident', 'demande', 'assistance', 'panne_materielle'], required: true },
      { name: 'priorite', label: 'Niveau de priorité', type: 'select', options: ['basse', 'moyenne', 'haute', 'critique'], required: true },
      { name: 'asset_id', label: 'Identifiant équipement concerné (optionnel)', type: 'number' },
      { name: 'description', label: 'Description détaillée', type: 'textarea', required: true, placeholder: 'Décrivez précisément le problème ou le besoin…' },
    ],
    editFields: [
      { name: 'titre', label: 'Sujet du ticket', required: true },
      { name: 'statut', label: 'État d’avancement', type: 'select', options: ['ouvert', 'en_cours', 'en_attente', 'resolu', 'ferme', 'annule'] },
      { name: 'priorite', label: 'Niveau de priorité', type: 'select', options: ['critique', 'haute', 'moyenne', 'basse'] },
      { name: 'type', label: 'Type de ticket', type: 'select', options: ['incident', 'demande', 'assistance', 'panne_materielle', 'maintenance'] },
      { name: 'description', label: 'Description', type: 'textarea', required: true },
    ],
  },
  '/licences': {
    title: 'Licences', subtitle: 'Logiciels et abonnements', endpoint: '/licences', canSearch: true,
    columns: [
      { key: 'nom', label: 'Logiciel' }, { key: 'editeur', label: 'Éditeur' },
      { key: 'quota_max', label: 'Quota' }, { key: 'date_expiration', label: 'Expiration' },
      { key: 'cout', label: 'Coût' },
    ],
    adminOnlyCreate: true,
    adminOnlyDelete: true,
    createFields: [
      { name: 'nom', label: 'Nom du logiciel', required: true },
      { name: 'editeur', label: 'Éditeur' },
      { name: 'cle_activation', label: 'Clé d’activation' },
      { name: 'date_expiration', label: 'Date d’expiration', type: 'date' },
      { name: 'quota_max', label: 'Nombre de licences', type: 'number' },
      { name: 'cout', label: 'Coût', type: 'number' },
      { name: 'notes', label: 'Notes', type: 'textarea' },
    ],
    editFields: [
      { name: 'nom', label: 'Nom du logiciel', required: true },
      { name: 'editeur', label: 'Éditeur' },
      { name: 'cle_activation', label: 'Clé d’activation' },
      { name: 'date_expiration', label: 'Date d’expiration', type: 'date' },
      { name: 'quota_max', label: 'Nombre de licences', type: 'number' },
      { name: 'cout', label: 'Coût', type: 'number' },
      { name: 'notes', label: 'Notes', type: 'textarea' },
    ],
  },
  '/consommables': {
    title: 'Consommables', subtitle: 'Stocks et mouvements', endpoint: '/consommables', canSearch: true,
    columns: [
      { key: 'nom', label: 'Consommable' }, { key: 'categorie', label: 'Catégorie' },
      { key: 'quantite', label: 'Quantité' }, { key: 'seuil_alerte', label: 'Seuil d’alerte' },
      { key: 'emplacement', label: 'Emplacement' },
    ],
    createFields: [
      { name: 'nom', label: 'Nom du consommable', required: true },
      { name: 'categorie', label: 'Catégorie' },
      { name: 'quantite', label: 'Quantité initiale', type: 'number' },
      { name: 'seuil_alerte', label: 'Seuil d’alerte', type: 'number' },
      { name: 'emplacement', label: 'Emplacement' },
    ],
    editFields: [
      { name: 'nom', label: 'Nom du consommable', required: true },
      { name: 'categorie', label: 'Catégorie' },
      { name: 'quantite', label: 'Quantité en stock', type: 'number', required: true },
      { name: 'seuil_alerte', label: 'Seuil d’alerte', type: 'number' },
      { name: 'emplacement', label: 'Emplacement' },
    ],
  },
  '/maintenances': {
    title: 'Maintenances', subtitle: 'Interventions et planning', endpoint: '/maintenances',
    columns: [
      { key: 'asset.asset_tag', label: 'Équipement' }, { key: 'date_prevue', label: 'Date prévue' },
      { key: 'type', label: 'Type' }, { key: 'description', label: 'Description' },
      { key: 'statut', label: 'État' },
    ],
    createFields: [
      { name: 'asset_id', label: 'Identifiant équipement', type: 'number', required: true },
      { name: 'date_prevue', label: 'Date prévue', type: 'date', required: true },
      { name: 'description', label: 'Description', type: 'textarea', required: true },
      { name: 'type', label: 'Type' },
      { name: 'technicien_id', label: 'Identifiant technicien', type: 'number' },
      { name: 'cout', label: 'Coût', type: 'number' },
    ],
    editFields: [
      { name: 'date_prevue', label: 'Date prévue', type: 'date', required: true },
      { name: 'statut', label: 'État de la maintenance', type: 'select', options: ['planifiee', 'en_cours', 'terminee', 'annulee'] },
      { name: 'type', label: 'Type d’intervention', type: 'select', options: ['preventive', 'corrective', 'evolutive'] },
      { name: 'description', label: 'Description des travaux', type: 'textarea', required: true },
      { name: 'cout', label: 'Coût', type: 'number' },
    ],
  },
  '/wiki': {
    title: 'Base de connaissances', subtitle: 'Guides et procédures IT', endpoint: '/wiki', canSearch: true,
    columns: [
      { key: 'titre', label: 'Titre' }, { key: 'categorie', label: 'Catégorie' },
      { key: 'auteur_nom', label: 'Auteur' }, { key: 'updated_at', label: 'Mis à jour' },
    ],
    createFields: [
      { name: 'titre', label: 'Titre de l’article', required: true },
      { name: 'categorie', label: 'Catégorie' },
      { name: 'contenu', label: 'Contenu', type: 'textarea', required: true },
      { name: 'est_public', label: 'Article public', type: 'checkbox' },
    ],
  },
  '/users': {
    title: 'Gestion des Accès', subtitle: 'Comptes applicatifs (Admin, Technicien, Lecteur)', endpoint: '/users', canSearch: true,
    columns: [
      { key: 'username', label: 'Identifiant' },
      { key: 'role', label: 'Rôle applicatif' },
      { key: 'nom', label: 'Nom' },
      { key: 'prenom', label: 'Prénom' },
      { key: 'email', label: 'Adresse e-mail' },
      { key: 'actif', label: 'État du compte' },
    ],
    adminOnlyCreate: true,
    createFields: [
      { name: 'username', label: 'Identifiant de connexion', required: true, placeholder: 'Ex: j.dupont' },
      { name: 'password', label: 'Mot de passe temporaire', type: 'password', required: true, placeholder: 'Min. 6 caractères' },
      { name: 'role', label: 'Rôle du compte', type: 'select', options: ['lecteur', 'technicien', 'admin'], required: true },
      { name: 'nom', label: 'Nom de famille', required: true },
      { name: 'prenom', label: 'Prénom', required: true },
      { name: 'email', label: 'Adresse e-mail professionnelle', type: 'email' },
    ],
  },
};

const navigation: NavigationItem[] = [
  { label: 'Tableau de bord', path: '/', icon: LayoutDashboard },
  { label: 'Mon Espace IT', path: '/mes-equipements', icon: UserCheck },
  { label: 'Inventaire du parc', path: '/assets', icon: Laptop },
  { label: 'Affectations', path: '/affectations', icon: ArrowLeftRight },
  { label: 'Tickets IT', path: '/tickets', icon: Ticket },
  { label: 'Licences', path: '/licences', icon: ShieldCheck },
  { label: 'Consommables', path: '/consommables', icon: Package },
  { label: 'Maintenances', path: '/maintenances', icon: Activity },
  { label: 'Audits & Inventaire', path: '/audits', icon: ClipboardCheck },
  { label: 'Base de connaissances', path: '/wiki', icon: BookOpen },
  { label: 'Gestion des Accès', path: '/users', icon: Users },
  { label: 'Journal d\'Audit', path: '/logs', icon: ShieldAlert },
  { label: 'Rapports', path: '/reports', icon: ChartNoAxesCombined },
  { label: 'Recherche globale', path: '/search', icon: Search },
  { label: 'Import / Export', path: '/import-export', icon: ArrowDownToLine },
];

const pageTitles: Record<string, { title: string; subtitle: string; icon: LucideIcon }> = {
  ...Object.fromEntries(Object.entries(modules).map(([path, module]) => [path, {
    title: module.title,
    subtitle: module.subtitle,
    icon: navigationIcon(path),
  }])),
  '/mes-equipements': { title: 'Mon Espace IT', subtitle: 'Mes équipements attribués et signalement rapide', icon: UserCheck },
  '/audits': { title: 'Audits & Inventaire', subtitle: 'Campagnes d\'inventaire physique et pointage terrain', icon: ClipboardCheck },
  '/logs': { title: 'Journal d\'Audit', subtitle: 'Traçabilité des actions et alertes e-mail', icon: ShieldAlert },
  '/reports': { title: 'Rapports', subtitle: 'Indicateurs et analyses', icon: ChartNoAxesCombined },
  '/search': { title: 'Recherche globale', subtitle: 'Retrouver rapidement une information', icon: Search },
  '/import-export': { title: 'Import / Export', subtitle: 'Échanger les données du parc', icon: ArrowDownToLine },
};

function navigationIcon(path: string): LucideIcon {
  return navigation.find((item) => item.path === path)?.icon ?? BriefcaseBusiness;
}

function initials(name?: string, username?: string) {
  const value = name?.trim() || username?.trim() || 'U';
  return value
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('');
}

function LoginPage() {
  const { login, user } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (user) return <Navigate to="/" replace />;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(username.trim(), password);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Connexion impossible.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <div className="login-art" aria-hidden="true">
        <div className="art-orbit orbit-one" />
        <div className="art-orbit orbit-two" />
        <div className="art-card">
          <div className="art-card-icon"><Boxes size={27} /></div>
          <div className="art-card-line line-long" />
          <div className="art-card-line line-short" />
          <div className="art-card-grid">
            <span><HardDrive size={19} /></span>
            <span><ShieldCheck size={19} /></span>
            <span><Activity size={19} /></span>
          </div>
        </div>
        <div className="art-copy">
          <span className="eyebrow">DIRECTION INFORMATIQUE · BOUAKÉ</span>
          <h2>Un parc maîtrisé,<br />une équipe efficace.</h2>
          <p>Inventaire, support et suivi de votre parc IT dans un espace unique.</p>
        </div>
      </div>
      <section className="login-panel">
        <div className="login-brand">
          <div className="brand-mark"><Boxes size={21} /></div>
          <div><strong>IT PARC</strong><span>Gestionnaire de parc</span></div>
        </div>
        <div className="login-form-wrap">
          <span className="eyebrow">ESPACE SÉCURISÉ</span>
          <h1>Bon retour</h1>
          <p className="muted">Connectez-vous pour accéder à votre espace de travail.</p>
          <form onSubmit={submit} className="login-form">
            <label htmlFor="username">Nom d’utilisateur</label>
            <input
              id="username"
              name="username"
              autoComplete="username"
              placeholder="Votre identifiant"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              required
            />
            <label htmlFor="password">Mot de passe</label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              placeholder="Votre mot de passe"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
            {error && <div className="form-error" role="alert">{error}</div>}
            <button className="button button-primary login-submit" disabled={loading}>
              {loading ? <span className="spinner" /> : null}
              {loading ? 'Connexion…' : 'Se connecter'}
            </button>
          </form>
          <div className="login-security"><ShieldCheck size={16} /> Connexion protégée par chiffrement</div>
        </div>
        <footer className="login-footer">© {new Date().getFullYear()} Direction IT · Bouaké</footer>
      </section>
    </main>
  );
}

function AppLayout() {
  const { token, user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [showScanner, setShowScanner] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [isOnline, setIsOnline] = useState(() => navigator.onLine);
  const [installPrompt, setInstallPrompt] = useState<(Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: string }> }) | null>(null);
  const title = location.pathname === '/' ? 'Tableau de bord' : pageTitles[location.pathname]?.title ?? 'Mon profil';
  const displayName = [user?.prenom, user?.nom].filter(Boolean).join(' ') || user?.username || 'Utilisateur';
  const role = (user?.role ?? 'lecteur').toLowerCase();
  const visibleNavigation = navigation.filter((item) => {
    if (item.path === '/users' || item.path === '/licences' || item.path === '/import-export' || item.path === '/logs') {
      return role === 'admin' || role === 'technicien';
    }
    return true;
  });

  const [darkMode, setDarkMode] = useState<boolean>(() => {
    return localStorage.getItem('parc-it-theme') === 'dark';
  });

  const [showNotifications, setShowNotifications] = useState(false);
  const [alertsSummary, setAlertsSummary] = useState<DashboardData | null>(null);
  const [pendingOfflineCount, setPendingOfflineCount] = useState<number>(() => getOfflineQueue().length);
  const [syncingOffline, setSyncingOffline] = useState(false);

  useEffect(() => {
    apiRequest<DashboardData>('/dashboard/stats', { token })
      .then((data) => setAlertsSummary(data))
      .catch(() => {});
  }, [token, location.pathname]);

  const alertCount =
    (alertsSummary?.stock_critique || 0) +
    (alertsSummary?.licences_expirant_bientot || 0) +
    (alertsSummary?.tickets_urgents || 0);

  useEffect(() => {
    if (darkMode) {
      document.documentElement.setAttribute('data-theme', 'dark');
      localStorage.setItem('parc-it-theme', 'dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
      localStorage.setItem('parc-it-theme', 'light');
    }
  }, [darkMode]);

  useEffect(() => {
    setMobileMenuOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    const refreshQueueCount = () => setPendingOfflineCount(getOfflineQueue().length);
    const handleOnline = () => {
      setIsOnline(true);
      if (token && getOfflineQueue().length > 0) {
        setSyncingOffline(true);
        void syncOfflineQueue(token).finally(() => setSyncingOffline(false));
      }
    };
    const handleOffline = () => setIsOnline(false);
    const handleInstallPrompt = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: string }> });
    };
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    window.addEventListener('beforeinstallprompt', handleInstallPrompt);
    window.addEventListener(OFFLINE_QUEUE_EVENT, refreshQueueCount);
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      window.removeEventListener('beforeinstallprompt', handleInstallPrompt);
      window.removeEventListener(OFFLINE_QUEUE_EVENT, refreshQueueCount);
    };
  }, [token]);

  async function installApp() {
    if (!installPrompt) return;
    await installPrompt.prompt();
    const choice = await installPrompt.userChoice;
    if (choice.outcome === 'accepted') setInstallPrompt(null);
  }

  return (
    <div className="app-shell">
      {!isOnline && (
        <div className="offline-banner" role="status">
          <CircleAlert size={16} /> Hors connexion — certaines données peuvent être indisponibles.
        </div>
      )}
      {mobileMenuOpen && <button className="mobile-backdrop" aria-label="Fermer le menu" onClick={() => setMobileMenuOpen(false)} />}
      <aside className={`sidebar ${mobileMenuOpen ? 'sidebar-open' : ''}`}>
        <Link className="brand" to="/">
          <div className="brand-mark"><Boxes size={21} /></div>
          <div className="brand-text"><strong>IT PARC</strong><span>Bouaké · Direction IT</span></div>
        </Link>
        <div className="sidebar-section-label">ESPACE DE TRAVAIL</div>
        <nav className="side-nav" aria-label="Navigation principale">
          {visibleNavigation.map(({ label, path, icon: Icon }) => (
            <NavLink key={path} to={path} end={path === '/'} onClick={() => setMobileMenuOpen(false)} className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}>
              <Icon size={18} strokeWidth={1.8} /><span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-bottom">
          <div className="sidebar-help"><CircleHelp size={17} /><span>Besoin d’aide ?</span></div>
          <button className="user-menu" onClick={() => void logout()} title="Se déconnecter">
            <div className="avatar">{initials(displayName, user?.username)}</div>
            <div className="user-meta"><strong>{displayName}</strong><span>{roleLabel(role)}</span></div>
            <LogOut size={17} className="logout-icon" />
          </button>
        </div>
      </aside>

      <div className="main-column">
        <header className="topbar">
          <button className="icon-button mobile-menu-button" onClick={() => setMobileMenuOpen(true)} aria-label="Ouvrir le menu"><Menu size={21} /></button>
          <div className="breadcrumb"><span>Parc informatique</span><span className="breadcrumb-separator">/</span><strong>{title}</strong></div>
          <div className="topbar-actions">
            {installPrompt && (
              <button className="install-button" onClick={() => void installApp()} title="Installer l’application">
                <ArrowDownToLine size={15} /><span>Installer</span>
              </button>
            )}
            <button
              className="theme-toggle-btn"
              onClick={() => setDarkMode(!darkMode)}
              title={darkMode ? 'Passer en mode clair' : 'Passer en mode sombre'}
              aria-label="Basculer le thème"
            >
              {darkMode ? <Sun size={17} /> : <Moon size={17} />}
            </button>
            <span className={`environment-pill ${isOnline ? '' : 'offline'}`}><span /> {isOnline ? 'En ligne' : 'Hors ligne'}</span>
            {pendingOfflineCount > 0 && (
              <button
                type="button"
                className="button button-secondary"
                disabled={!isOnline || syncingOffline}
                onClick={() => {
                  setSyncingOffline(true);
                  void syncOfflineQueue(token).finally(() => setSyncingOffline(false));
                }}
                title={isOnline ? 'Synchroniser les actions hors-ligne maintenant' : 'En attente de connexion réseau'}
                style={{ padding: '4px 10px', fontSize: 11, height: 28, background: '#fef3c7', color: '#92400e', borderColor: '#fde68a', display: 'inline-flex', alignItems: 'center', gap: 5 }}
              >
                <RefreshCw size={12} />
                <span>{syncingOffline ? 'Sync...' : `${pendingOfflineCount} en attente`}</span>
              </button>
            )}
            <button
              type="button"
              className="icon-button"
              onClick={() => setShowScanner(true)}
              title="Scanner un QR Code d'équipement (Caméra)"
              aria-label="Scanner QR Code"
              style={{ color: '#0284c7' }}
            >
              <ScanLine size={18} />
            </button>
            <Link to="/search" className="icon-button" title="Recherche rapide" aria-label="Recherche">
              <Search size={18} />
            </Link>
            <div className="notification-wrapper">
              <button
                type="button"
                className="icon-button notification-button"
                onClick={() => setShowNotifications(!showNotifications)}
                title="Notifications & alertes"
                aria-label="Centre de notifications"
                style={{ position: 'relative' }}
              >
                <Bell size={18} />
                {alertCount > 0 && <span className="notification-badge-dot">{alertCount}</span>}
              </button>
              {showNotifications && (
                <div className="notification-popover" onClick={(e) => e.stopPropagation()}>
                  <div className="notification-popover-header">
                    <span>Alertes Opérationnelles</span>
                    <span style={{ fontSize: 10, background: alertCount > 0 ? '#fee2e2' : '#f0fdf4', color: alertCount > 0 ? '#991b1b' : '#16a34a', padding: '2px 7px', borderRadius: 10 }}>
                      {alertCount} active{alertCount > 1 ? 's' : ''}
                    </span>
                  </div>
                  <div className="notification-popover-list">
                    {Boolean(alertsSummary?.stock_critique && alertsSummary.stock_critique > 0) && (
                      <Link
                        to="/consommables"
                        className="notification-popover-item"
                        onClick={() => setShowNotifications(false)}
                      >
                        <div className="pro-icon-box red" style={{ width: 26, height: 26 }}>
                          <Package size={13} />
                        </div>
                        <div>
                          <strong style={{ fontSize: 11, display: 'block' }}>{alertsSummary?.stock_critique} consommable(s) sous le seuil</strong>
                          <span style={{ fontSize: 10, color: '#64748b' }}>Stock critique à réapprovisionner</span>
                        </div>
                      </Link>
                    )}
                    {Boolean(alertsSummary?.licences_expirant_bientot && alertsSummary.licences_expirant_bientot > 0) && (
                      <Link
                        to="/licences"
                        className="notification-popover-item"
                        onClick={() => setShowNotifications(false)}
                      >
                        <div className="pro-icon-box amber" style={{ width: 26, height: 26 }}>
                          <ShieldCheck size={13} />
                        </div>
                        <div>
                          <strong style={{ fontSize: 11, display: 'block' }}>{alertsSummary?.licences_expirant_bientot} licence(s) à renouveler</strong>
                          <span style={{ fontSize: 10, color: '#64748b' }}>Expiration sous 90 jours</span>
                        </div>
                      </Link>
                    )}
                    {Boolean(alertsSummary?.tickets_urgents && alertsSummary.tickets_urgents > 0) && (
                      <Link
                        to="/tickets"
                        className="notification-popover-item"
                        onClick={() => setShowNotifications(false)}
                      >
                        <div className="pro-icon-box red" style={{ width: 26, height: 26 }}>
                          <Ticket size={13} />
                        </div>
                        <div>
                          <strong style={{ fontSize: 11, display: 'block' }}>{alertsSummary?.tickets_urgents} ticket(s) urgent(s)</strong>
                          <span style={{ fontSize: 10, color: '#64748b' }}>Pannes ou incidents critiques</span>
                        </div>
                      </Link>
                    )}
                    {alertCount === 0 && (
                      <div style={{ padding: '16px 12px', textAlign: 'center', color: '#64748b', fontSize: 11 }}>
                        ✅ Aucune alerte active. Tous les voyants du parc sont au vert.
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
            <Link to="/profile" className="topbar-user" title="Voir mon profil">
              <div className="avatar avatar-small">{initials(displayName, user?.username)}</div>
              <ChevronDown size={15} />
            </Link>
          </div>
        </header>
        <QrScannerModal
          isOpen={showScanner}
          onClose={() => setShowScanner(false)}
          onScan={(code) => {
            navigate(`/search?q=${encodeURIComponent(code)}`);
          }}
        />
        <main className="page-content">
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            {Object.keys(modules).map((path) => (
              <Route key={path} path={path} element={<ModulePage path={path} />} />
            ))}
            <Route path="/mes-equipements" element={<MonEspacePage />} />
            <Route path="/audits" element={<AuditsPage />} />
            <Route path="/logs" element={<ActivityLogsPage />} />
            <Route path="/search" element={<SearchPage />} />
            <Route path="/reports" element={<ReportsPage />} />
            <Route path="/import-export" element={<ImportExportPage />} />
            <Route path="/profile" element={<ProfilePage />} />
            <Route path="*" element={<NotFoundPage />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function roleLabel(role: string) {
  if (role === 'admin') return 'ADMINISTRATEUR';
  if (role === 'technicien') return 'TECHNICIEN';
  return 'LECTEUR';
}

function formatAssetType(type: string): { label: string; icon: LucideIcon } {
  const t = (type || '').toLowerCase().trim();
  if (t === 'laptop' || t === 'portable' || t === 'pc_portable') return { label: 'Ordinateurs Portables', icon: Laptop };
  if (t === 'desktop' || t === 'fixe' || t === 'pc_fixe' || t === 'poste_fixe') return { label: 'Postes Fixes / Desktop', icon: Monitor };
  if (t.includes('pax') || t.includes('tpe') || t.includes('terminal')) return { label: 'Terminaux PAX / TPE', icon: CreditCard };
  if (t === 'ecran' || t === 'moniteur' || t === 'monitor') return { label: 'Écrans & Moniteurs', icon: Tv };
  if (t === 'telephone' || t === 'smartphone' || t === 'mobile') return { label: 'Smartphones & Mobiles', icon: Smartphone };
  if (t === 'imprimante' || t === 'printer' || t === 'copieur') return { label: 'Imprimantes & Copieurs', icon: Printer };
  if (t === 'serveur' || t === 'server') return { label: 'Serveurs & Baies', icon: Server };
  if (t === 'tablette' || t === 'tablet') return { label: 'Tablettes Tactiles', icon: Tablet };
  return { label: type.charAt(0).toUpperCase() + type.slice(1).replace(/_/g, ' '), icon: HardDrive };
}

function formatAssetStatus(statut: string): { label: string; icon: LucideIcon; boxTone: string; gradient: string } {
  const s = (statut || '').toLowerCase().trim();
  if (s.includes('service') || s === 'actif') {
    return { label: 'En service (Opérationnel)', icon: Activity, boxTone: 'green', gradient: 'linear-gradient(90deg, #10b981 0%, #059669 100%)' };
  }
  if (s.includes('stock')) {
    return { label: 'En stock (Disponible)', icon: Package, boxTone: 'blue', gradient: 'linear-gradient(90deg, #3b82f6 0%, #2563eb 100%)' };
  }
  if (s.includes('maintenance')) {
    return { label: 'En maintenance (Révision/SAV)', icon: Settings, boxTone: 'amber', gradient: 'linear-gradient(90deg, #f59e0b 0%, #d97706 100%)' };
  }
  if (s.includes('hors') || s.includes('panne')) {
    return { label: 'Hors service (Défaillant)', icon: CircleAlert, boxTone: 'red', gradient: 'linear-gradient(90deg, #ef4444 0%, #b91c1c 100%)' };
  }
  if (s.includes('reforme') || s.includes('réforme') || s.includes('rebut')) {
    return { label: 'Réformé / Mis au rebut', icon: Archive, boxTone: 'gray', gradient: 'linear-gradient(90deg, #94a3b8 0%, #64748b 100%)' };
  }
  return { label: statut ? statut.replace(/_/g, ' ') : 'Inconnu', icon: Activity, boxTone: 'gray', gradient: 'linear-gradient(90deg, #64748b, #475569)' };
}

function DashboardPage() {
  const { token } = useAuth();
  const [stats, setStats] = useState<DashboardData | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  async function loadStats() {
    setLoading(true);
    setError('');
    try {
      setStats(await apiRequest<DashboardData>('/dashboard/stats', { token }));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Impossible de récupérer les statistiques.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadStats();
  }, [token]);

  const total = stats?.totaux?.total ?? 0;
  const cards = useMemo(() => [
    { label: 'Équipements recensés', value: total, icon: Laptop, tone: 'blue', note: 'Total du parc', to: '/assets' },
    { label: 'Alertes de sécurité', value: stats?.non_conformes ?? 0, icon: ShieldCheck, tone: 'orange', note: 'À vérifier dans les rapports', to: '/reports' },
    { label: 'En service', value: stats?.totaux?.en_service ?? 0, icon: Activity, tone: 'green', note: 'Équipements actifs', to: '/assets?statut=en_service' },
    { label: 'En maintenance', value: stats?.totaux?.en_maintenance ?? 0, icon: Settings, tone: 'yellow', note: 'Suivi en cours', to: '/assets?statut=en_maintenance' },
  ], [stats, total]);

  return (
    <div className="dashboard-page">
      <div className="page-heading">
        <div>
          <span className="eyebrow">VUE D’ENSEMBLE</span>
          <h1>Tableau de bord</h1>
          <p>Suivez l’état de votre parc informatique en temps réel.</p>
        </div>
        <button className="button button-secondary" onClick={() => void loadStats()} disabled={loading}>
          <Activity size={16} /> Actualiser
        </button>
      </div>

      {error && (
        <div className="alert alert-error" role="alert">
          <div><strong>Impossible de charger les statistiques</strong><span>{error}</span></div>
          <button className="button button-secondary" onClick={() => void loadStats()}>Réessayer</button>
        </div>
      )}

      {Boolean(
        (stats?.stock_critique && stats.stock_critique > 0) ||
        (stats?.licences_expirant_bientot && stats.licences_expirant_bientot > 0) ||
        (stats?.tickets_urgents && stats.tickets_urgents > 0) ||
        (stats?.non_conformes && stats.non_conformes > 0)
      ) && (
        <div className="dashboard-alerts-banner">
          <div className="alerts-banner-title">
            <AlertTriangle size={16} /> Alertes opérationnelles :
          </div>
          {Boolean(stats?.stock_critique && stats.stock_critique > 0) && (
            <Link to="/consommables" className="alert-pill-item alert-pill-red" title="Consommables sous le seuil d'alerte">
              <Package size={13} /> {stats?.stock_critique} stock{stats?.stock_critique && stats.stock_critique > 1 ? 's' : ''} critique{stats?.stock_critique && stats.stock_critique > 1 ? 's' : ''}
            </Link>
          )}
          {Boolean(stats?.licences_expirant_bientot && stats.licences_expirant_bientot > 0) && (
            <Link to="/licences" className="alert-pill-item alert-pill-amber" title="Licences à renouveler sous 90 jours">
              <ShieldCheck size={13} /> {stats?.licences_expirant_bientot} licence{stats?.licences_expirant_bientot && stats.licences_expirant_bientot > 1 ? 's' : ''} à renouveler
            </Link>
          )}
          {Boolean(stats?.tickets_urgents && stats.tickets_urgents > 0) && (
            <Link to="/tickets" className="alert-pill-item alert-pill-red" title="Tickets d'incidents ou pannes prioritaires">
              <Ticket size={13} /> {stats?.tickets_urgents} ticket{stats?.tickets_urgents && stats.tickets_urgents > 1 ? 's' : ''} prioritaire{stats?.tickets_urgents && stats.tickets_urgents > 1 ? 's' : ''}
            </Link>
          )}
          {Boolean(stats?.non_conformes && stats.non_conformes > 0) && (
            <Link to="/reports" className="alert-pill-item alert-pill-blue" title="Équipements avec contrôles de sécurité incomplets">
              <Laptop size={13} /> {stats?.non_conformes} anomalie{stats?.non_conformes && stats.non_conformes > 1 ? 's' : ''} sécurité
            </Link>
          )}
        </div>
      )}

      <div className="stats-grid">
        {cards.map(({ label, value, icon: Icon, tone, note, to }) => (
          <Link className={`stat-card stat-card-link tone-${tone}`} key={label} to={to} aria-label={`${label} : consulter les données`}>
            <div className={`stat-icon ${tone}`}><Icon size={19} /></div>
            <div className="stat-label">{label}</div>
            <div className="stat-value">{loading ? <span className="skeleton-number" /> : value.toLocaleString('fr-FR')}</div>
            <div className="stat-note">{note}</div>
            <div className="stat-link-hint">Consulter <ArrowRight size={13} /></div>
          </Link>
        ))}
      </div>

      <div className="dashboard-columns">
        <section className="panel pro-card">
          <div className="panel-heading">
            <div>
              <h2 style={{ fontSize: 14, fontWeight: 700 }}>Répartition du parc</h2>
              <p style={{ fontSize: 11 }}>Équipements par catégorie matérielle</p>
            </div>
            <div className="panel-heading-icon"><Boxes size={18} /></div>
          </div>
          {loading ? (
            <div className="loading-lines"><i /><i /><i /></div>
          ) : (
            <div className="pro-bar-list">
              {(stats?.par_type ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                const info = formatAssetType(item.type);
                const Icon = info.icon;
                const pct = total > 0 ? Math.round((item.count / total) * 100) : 0;
                return (
                  <Link
                    to={`/assets?search=${encodeURIComponent(item.type)}`}
                    className="pro-dashboard-row"
                    key={`${item.type}-${index}`}
                    title={`Voir les ${info.label}`}
                  >
                    <div className="pro-row-top">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <div className="pro-icon-box blue">
                          <Icon size={14} />
                        </div>
                        <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>
                          {info.label}
                        </span>
                      </div>
                      <div className="pro-metric-badge">
                        <strong>{item.count}</strong>
                        <span style={{ color: '#94a3b8', fontSize: 10, marginLeft: 4 }}>({pct}%)</span>
                      </div>
                    </div>
                    <div className="pro-bar-track">
                      <span
                        style={{
                          width: `${(item.count / max) * 100}%`,
                          background: 'linear-gradient(90deg, #3b82f6 0%, #6366f1 100%)',
                        }}
                      />
                    </div>
                  </Link>
                );
              })}
              {!stats?.par_type?.length && <EmptyState text="Aucune donnée de répartition disponible." />}
            </div>
          )}
        </section>

        <section className="panel pro-card">
          <div className="panel-heading">
            <div>
              <h2 style={{ fontSize: 14, fontWeight: 700 }}>Conformité de sécurité</h2>
              <p style={{ fontSize: 11 }}>État des protections et agents IT</p>
            </div>
            <div className="panel-heading-icon green"><ShieldCheck size={18} /></div>
          </div>
          
          <div className="pro-compliance-score-box">
            <div className="pro-score-circle">
              <span className="pro-score-val">{loading ? '—' : `${Math.round(stats?.securite?.score_conformite ?? 0)}%`}</span>
            </div>
            <div className="pro-score-meta">
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 12, color: '#0f172a' }}>Score Global de Conformité</strong>
                <span
                  className={`status-badge ${(stats?.securite?.score_conformite ?? 0) >= 75 ? 'status-green' : (stats?.securite?.score_conformite ?? 0) >= 50 ? 'status-amber' : 'status-red'}`}
                  style={{ fontSize: 9, padding: '2px 7px' }}
                >
                  {(stats?.securite?.score_conformite ?? 0) >= 75 ? 'Sécurité Conforme' : (stats?.securite?.score_conformite ?? 0) >= 50 ? 'Attention Requise' : 'Critique'}
                </span>
              </div>
              <p style={{ margin: '4px 0 0', fontSize: 10, color: '#64748b' }}>
                Audit en temps réel sur {stats?.securite?.total_avec_securite || total} équipements suivis
              </p>
            </div>
          </div>

          <div className="pro-bar-list" style={{ marginTop: 10 }}>
            <ComplianceRow label="Microsoft Defender (Antivirus)" value={stats?.securite?.defender_ok} total={stats?.securite?.total_avec_securite} icon={Shield} />
            <ComplianceRow label="Chiffrement BitLocker" value={stats?.securite?.bitlocker_ok} total={stats?.securite?.total_avec_securite} icon={Lock} />
            <ComplianceRow label="Microsoft Intune (MDM)" value={stats?.securite?.intune_ok} total={stats?.securite?.total_avec_securite} icon={Smartphone} />
          </div>
        </section>
      </div>

      <div className="dashboard-columns" style={{ marginTop: 16 }}>
        <section className="panel pro-card">
          <div className="panel-heading">
            <div>
              <h2 style={{ fontSize: 14, fontWeight: 700 }}>Répartition par site</h2>
              <p style={{ fontSize: 11 }}>Implantation géographique des machines</p>
            </div>
            <div className="panel-heading-icon"><Building2 size={18} /></div>
          </div>
          {loading ? (
            <div className="loading-lines"><i /><i /><i /></div>
          ) : (
            <div className="pro-bar-list">
              {(stats?.par_site ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                const pct = total > 0 ? Math.round((item.count / total) * 100) : 0;
                return (
                  <Link
                    to={`/assets?search=${encodeURIComponent(item.site)}`}
                    className="pro-dashboard-row"
                    key={`${item.site}-${index}`}
                    title={`Filtrer par site : ${item.site}`}
                  >
                    <div className="pro-row-top">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <div className="pro-icon-box sky">
                          <MapPin size={14} />
                        </div>
                        <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>
                          {item.site}
                        </span>
                      </div>
                      <div className="pro-metric-badge">
                        <strong>{item.count} machine{item.count > 1 ? 's' : ''}</strong>
                        <span style={{ color: '#94a3b8', fontSize: 10, marginLeft: 4 }}>({pct}%)</span>
                      </div>
                    </div>
                    <div className="pro-bar-track">
                      <span
                        style={{
                          width: `${(item.count / max) * 100}%`,
                          background: 'linear-gradient(90deg, #0284c7 0%, #38bdf8 100%)',
                        }}
                      />
                    </div>
                  </Link>
                );
              })}
              {!stats?.par_site?.length && <EmptyState text="Aucune donnée de site disponible." />}
            </div>
          )}
        </section>

        <section className="panel pro-card">
          <div className="panel-heading">
            <div>
              <h2 style={{ fontSize: 14, fontWeight: 700 }}>Répartition par département</h2>
              <p style={{ fontSize: 11 }}>Directions et services utilisateurs</p>
            </div>
            <div className="panel-heading-icon green"><PieChart size={18} /></div>
          </div>
          {loading ? (
            <div className="loading-lines"><i /><i /><i /></div>
          ) : (
            <div className="pro-bar-list">
              {(stats?.par_departement ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                const pct = total > 0 ? Math.round((item.count / total) * 100) : 0;
                return (
                  <Link
                    to={`/assets?search=${encodeURIComponent(item.departement)}`}
                    className="pro-dashboard-row"
                    key={`${item.departement}-${index}`}
                    title={`Filtrer par département : ${item.departement}`}
                  >
                    <div className="pro-row-top">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <div className="pro-icon-box emerald">
                          <BriefcaseBusiness size={14} />
                        </div>
                        <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>
                          {item.departement}
                        </span>
                      </div>
                      <div className="pro-metric-badge">
                        <strong>{item.count} machine{item.count > 1 ? 's' : ''}</strong>
                        <span style={{ color: '#94a3b8', fontSize: 10, marginLeft: 4 }}>({pct}%)</span>
                      </div>
                    </div>
                    <div className="pro-bar-track">
                      <span
                        style={{
                          width: `${(item.count / max) * 100}%`,
                          background: 'linear-gradient(90deg, #059669 0%, #10b981 100%)',
                        }}
                      />
                    </div>
                  </Link>
                );
              })}
              {!stats?.par_departement?.length && <EmptyState text="Aucune donnée de département disponible." />}
            </div>
          )}
        </section>
      </div>

      <section className="panel recent-panel pro-card">
        <div className="panel-heading">
          <div><h2 style={{ fontSize: 14, fontWeight: 700 }}>Équipements récemment ajoutés</h2><p style={{ fontSize: 11 }}>Dernières entrées de l’inventaire</p></div>
          <Link className="text-link" to="/assets">Voir l’inventaire <span>→</span></Link>
        </div>
        {loading ? <div className="loading-lines"><i /><i /><i /></div> : (
          <div className="table-scroll">
            <table className="data-table">
              <thead><tr><th>Équipement</th><th>Type</th><th>Site</th><th>État</th></tr></thead>
              <tbody>
                {(stats?.recents ?? []).slice(0, 5).map((asset) => (
                  <tr key={asset.id}>
                    <td><div className="asset-name"><div className="table-icon"><Laptop size={16} /></div><div><strong>{asset.asset_tag || asset.nom_machine || `Équipement #${asset.id}`}</strong><span>{[asset.marque, asset.modele].filter(Boolean).join(' ')}</span></div></div></td>
                    <td>{asset.type || '—'}</td>
                    <td>{asset.site || '—'}</td>
                    <td><span className={`status-badge ${statusTone(asset.statut)}`}>{asset.statut || 'Inconnu'}</span></td>
                  </tr>
                ))}
                {!stats?.recents?.length && <tr><td colSpan={4}><EmptyState text="Aucun équipement récent." /></td></tr>}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

function ComplianceRow({
  label,
  value = 0,
  total = 0,
  icon: Icon = Shield,
}: {
  label: string;
  value?: number;
  total?: number;
  icon?: LucideIcon;
}) {
  const percent = total ? Math.min(100, Math.round((value / total) * 100)) : 0;
  const gradient =
    percent >= 80
      ? 'linear-gradient(90deg, #10b981 0%, #059669 100%)'
      : percent >= 50
      ? 'linear-gradient(90deg, #f59e0b 0%, #d97706 100%)'
      : 'linear-gradient(90deg, #ef4444 0%, #b91c1c 100%)';

  const badgeClass =
    percent >= 80 ? 'status-green' : percent >= 50 ? 'status-amber' : 'status-red';

  return (
    <div className="pro-dashboard-row" style={{ padding: '6px 8px' }}>
      <div className="pro-row-top">
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
          <div className="pro-icon-box green">
            <Icon size={14} />
          </div>
          <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>{label}</span>
        </div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 10, color: '#64748b' }}>
            {value}/{total} postes
          </span>
          <span className={`status-badge ${badgeClass}`} style={{ fontSize: 10, fontWeight: 700, padding: '1px 7px' }}>
            {percent}%
          </span>
        </div>
      </div>
      <div className="pro-bar-track">
        <span style={{ width: `${percent}%`, background: gradient }} />
      </div>
    </div>
  );
}

function statusTone(value?: string) {
  const normalized = value?.toLowerCase() ?? '';
  if (normalized.includes('service') || normalized.includes('actif') || normalized.includes('resolu') || normalized.includes('cloture')) return 'status-green';
  if (normalized.includes('maintenance') || normalized.includes('cours') || normalized.includes('attente')) return 'status-amber';
  if (normalized.includes('hors') || normalized.includes('réforme') || normalized.includes('reforme') || normalized.includes('rejete')) return 'status-red';
  if (normalized.includes('stock') || normalized.includes('nouveau') || normalized.includes('ouvert')) return 'status-blue';
  return 'status-gray';
}

function priorityBadge(value?: string) {
  const normalized = value?.toLowerCase() ?? '';
  if (normalized.includes('critique') || normalized.includes('urgente')) return 'badge-critique';
  if (normalized.includes('haute') || normalized.includes('elevee')) return 'badge-haute';
  if (normalized.includes('moyenne')) return 'badge-moyenne';
  if (normalized.includes('basse') || normalized.includes('faible')) return 'badge-basse';
  return 'status-gray';
}

function EmptyState({ text }: { text: string }) {
  return <div className="empty-state"><Archive size={19} /><span>{text}</span></div>;
}

function getEditFieldValue(record: Record<string, unknown>, field: FormFieldDefinition) {
  const asset = asRecord(record.asset);
  const user = asRecord(record.user);
  const values: Record<string, unknown> = {
    asset_tag: record.asset_tag ?? record['Nom Machine'],
    asset_id: record.asset_id ?? asset?.id,
    nom: record.user_nom ?? user?.nom ?? record.nom,
    prenom: record.user_prenom ?? user?.prenom ?? record.prenom,
    departement: record.departement ?? user?.departement,
    site: record.site ?? user?.site,
  };
  const value = values[field.name] ?? record[field.name];
  if (field.type === 'checkbox') return value === true || value === 1 || value === '1';
  if (value === null || value === undefined) return '';
  const text = String(value);
  return field.type === 'date' ? text.slice(0, 10) : text;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function extractRows(value: unknown, depth = 0): Record<string, unknown>[] {
  if (depth > 3) return [];
  if (Array.isArray(value)) return value.map(asRecord).filter((row): row is Record<string, unknown> => row !== null);
  const record = asRecord(value);
  if (!record) return [];
  for (const key of ['items', 'rows', 'results', 'data']) {
    if (Array.isArray(record[key])) return extractRows(record[key], depth + 1);
  }
  for (const key of ['data', 'result']) {
    if (record[key] !== undefined) {
      const nested = extractRows(record[key], depth + 1);
      if (nested.length) return nested;
    }
  }
  return [];
}

function getPath(record: Record<string, unknown>, path: string): unknown {
  const direct = record[path];
  if (direct !== undefined) return direct;
  const nested = path.split('.').reduce<unknown>((value, key) => asRecord(value)?.[key], record);
  if (nested !== undefined) return nested;
  if (path === 'asset.asset_tag') return record.asset_tag ?? record['Nom Machine'] ?? record.nom_machine;
  if (path === 'user.nom') return record.user_nom ?? record.nom ?? record.utilisateur_nom;
  if (path === 'user.prenom') return record.user_prenom ?? record.prenom;
  if (path === 'user.departement') return record.departement ?? record.user_dept;
  if (path === 'user.site') return record.site ?? record.user_site;
  return undefined;
}

function cellText(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return value.toLocaleString('fr-FR');
  if (Array.isArray(value)) return value.map(cellText).join(', ');
  const object = asRecord(value);
  if (object) {
    const name = [object.prenom, object.nom].filter((part): part is string => typeof part === 'string').join(' ');
    return name || String(object.asset_tag ?? object.nom_machine ?? object.titre ?? object.id ?? '—');
  }
  return String(value);
}

function ModulePage({ path }: { path: string }) {
  const definition = modules[path];
  const { token, user } = useAuth();
  const [searchParams] = useSearchParams();
  const statusFilter = path === '/assets' ? searchParams.get('statut') : null;
  const [payload, setPayload] = useState<unknown>(null);
  const [query, setQuery] = useState('');
  const [submittedQuery, setSubmittedQuery] = useState('');
  const [page, setPage] = useState(1);
  const [refreshKey, setRefreshKey] = useState(0);
  const [selectedRow, setSelectedRow] = useState<Record<string, unknown> | null>(null);
  const [sortField, setSortField] = useState<string | null>(null);
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [siteFilter, setSiteFilter] = useState('');
  const [deptFilter, setDeptFilter] = useState('');
  const [statutFilterState, setStatutFilterState] = useState('');

  const rows = useMemo(() => extractRows(payload), [payload]);
  const filteredRows = useMemo(() => {
    let result = rows;
    if (siteFilter) {
      const q = siteFilter.toLowerCase();
      result = result.filter((r) => {
        const s = String(r.site ?? (asRecord(r.user)?.site) ?? '').toLowerCase();
        return s.includes(q);
      });
    }
    if (deptFilter) {
      const q = deptFilter.toLowerCase();
      result = result.filter((r) => {
        const d = String(r.departement ?? (asRecord(r.user)?.departement) ?? '').toLowerCase();
        return d.includes(q);
      });
    }
    if (statutFilterState && path === '/assets') {
      result = result.filter((r) => String(r.statut ?? '').toLowerCase() === statutFilterState.toLowerCase());
    }
    return result;
  }, [rows, siteFilter, deptFilter, statutFilterState, path]);

  const sortedRows = useMemo(() => {
    if (!sortField) return filteredRows;
    return [...filteredRows].sort((a, b) => {
      const valA = String(getPath(a, sortField) ?? '').toLowerCase();
      const valB = String(getPath(b, sortField) ?? '').toLowerCase();
      if (valA < valB) return sortOrder === 'asc' ? -1 : 1;
      if (valA > valB) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [filteredRows, sortField, sortOrder]);

  function handleSort(key: string) {
    if (sortField === key) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(key);
      setSortOrder('asc');
    }
  }
  const [createOpen, setCreateOpen] = useState(false);
  const [editingRow, setEditingRow] = useState<Record<string, unknown> | null>(null);
  const [successMessage, setSuccessMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [downloadingPdfId, setDownloadingPdfId] = useState<number | null>(null);
  const [qrModalAsset, setQrModalAsset] = useState<{ id: number; tag: string; dataUrl: string; asset: Record<string, unknown> } | null>(null);
  const [showBatchLabels, setShowBatchLabels] = useState(false);
  const [signingAff, setSigningAff] = useState<{ id: number; tag: string; user: string } | null>(null);

  // États pour la restitution 1-clic
  const [restitutionItem, setRestitutionItem] = useState<Record<string, unknown> | null>(null);
  const [restitutionMotif, setRestitutionMotif] = useState('Départ collaborateur / Fin de mission');
  const [restitutionStatut, setRestitutionStatut] = useState('en_stock');
  const [isSubmittingRestitution, setIsSubmittingRestitution] = useState(false);

  // États pour la Timeline et l'historique complet d'un équipement
  const [assetDetail, setAssetDetail] = useState<Record<string, unknown> | null>(null);
  const [activeModalTab, setActiveModalTab] = useState<'info' | 'history'>('info');
  const [loadingAssetDetail, setLoadingAssetDetail] = useState(false);

  useEffect(() => {
    if (selectedRow && path === '/assets' && selectedRow.id) {
      setActiveModalTab('info');
      setLoadingAssetDetail(true);
      apiRequest<Record<string, unknown>>(`/assets/${selectedRow.id}`, { token })
        .then((data) => setAssetDetail(data))
        .catch(() => setAssetDetail(null))
        .finally(() => setLoadingAssetDetail(false));
    } else {
      setAssetDetail(null);
    }
  }, [selectedRow, path, token]);

  async function handleConfirmRestitution() {
    if (!restitutionItem) return;
    setIsSubmittingRestitution(true);
    try {
      const affId = Number(restitutionItem.id);
      const assetId = Number(restitutionItem.asset_id);
      await apiRequest(`/affectations/${affId}/restitution`, {
        method: 'POST',
        token,
        body: {
          motif: restitutionMotif,
          nouveau_statut: restitutionStatut,
          asset_id: assetId,
        },
      });
      setSuccessMessage('Équipement restitué et réintégré au stock avec succès ! Procès-verbal téléchargé.');
      void handleDownloadRestitutionPdf(affId, String(restitutionItem.asset_tag ?? ''));
      setRestitutionItem(null);
      setRefreshKey((c) => c + 1);
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur lors de la restitution');
    } finally {
      setIsSubmittingRestitution(false);
    }
  }

  function handleExportCsv() {
    const slug = path.replace('/', '') || 'export';
    const date = new Date().toISOString().split('T')[0];
    exportToCsv(`${slug}_${date}.csv`, definition.columns, filteredRows);
  }

  async function handleShowQr(assetId: number, tag?: string) {
    try {
      const res = await apiRequest<{ dataUrl: string; asset: Record<string, unknown> }>(`/assets/${assetId}/qr`, { token });
      setQrModalAsset({ id: assetId, tag: tag || String(assetId), dataUrl: res.dataUrl, asset: res.asset });
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Erreur chargement QR Code');
    }
  }

  async function handleDownloadPdf(affectationId: number, tag?: string) {
    try {
      setDownloadingPdfId(affectationId);
      const blob = await apiDownload(`/affectations/${affectationId}/pdf`, { token });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Fiche_Affectation_${tag || affectationId}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur lors du téléchargement du PDF');
    } finally {
      setDownloadingPdfId(null);
    }
  }

  async function handleDownloadRestitutionPdf(affectationId: number, tag?: string) {
    try {
      setDownloadingPdfId(affectationId);
      const blob = await apiDownload(`/affectations/${affectationId}/restitution-pdf`, { token });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Fiche_Restitution_${tag || affectationId}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur lors du téléchargement du PV de restitution');
    } finally {
      setDownloadingPdfId(null);
    }
  }

  async function handleDownloadAssetPdf(assetId: number, tag?: string) {
    try {
      setDownloadingPdfId(assetId);
      const blob = await apiDownload(`/assets/${assetId}/pdf`, { token });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Fiche_Technique_${tag || assetId}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur lors du téléchargement de la fiche technique');
    } finally {
      setDownloadingPdfId(null);
    }
  }

  async function handleSignedPdf(signatureDataUrl: string) {
    if (!signingAff) return;
    try {
      setDownloadingPdfId(signingAff.id);
      const blob = await apiDownload(`/affectations/${signingAff.id}/pdf`, {
        token,
        method: 'POST',
        body: { signature: signatureDataUrl },
      });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Fiche_Affectation_Signee_${signingAff.tag || signingAff.id}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();
      setSuccessMessage('PV émargé avec succès et téléchargé en PDF.');
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Erreur lors de la génération du PDF signé');
    } finally {
      setDownloadingPdfId(null);
    }
  }

  const details = pageTitles[path];
  const totalCount = asRecord(payload)?.total;
  const canNextPage = definition.paginated && (
    typeof totalCount === 'number' ? page * 20 < totalCount : rows.length === 20
  );
  const role = (user?.role ?? '').toLowerCase();
  const canCreate = Boolean(
    definition.createFields &&
    (definition.adminOnlyCreate
      ? role === 'admin'
      : path === '/tickets' || role === 'admin' || role === 'technicien'),
  );
  const targetModules = ['/affectations', '/assets', '/consommables', '/licences'];
  const canEdit = Boolean(
    definition.editFields &&
    (targetModules.includes(path) || role === 'admin' || role === 'technicien'),
  );
  const canDelete = Boolean(
    definition.editFields &&
    (targetModules.includes(path) || role === 'admin' || role === 'technicien'),
  );

  async function deleteRow(row: Record<string, unknown>) {
    const id = Number(row.id);
    if (!Number.isInteger(id) || id <= 0) {
      setError('Impossible de supprimer cet élément : identifiant invalide.');
      return;
    }
    const label = String(row.asset_tag ?? row['Nom Machine'] ?? row.nom ?? row.titre ?? `#${id}`);
    if (!window.confirm(`Voulez-vous vraiment supprimer « ${label} » ?`)) return;

    try {
      await apiRequest<unknown>(`${definition.endpoint}/${id}`, {
        method: 'DELETE',
        token,
        ...(path === '/assets' ? { body: { motif: 'Supprimé depuis l’inventaire' } } : {}),
      });
      setSuccessMessage('Enregistrement supprimé avec succès.');
      setRefreshKey((current) => current + 1);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'La suppression a échoué.');
    }
  }

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError('');
    apiRequest<unknown>(definition.endpoint, {
      token,
      query: {
        ...(definition.paginated ? { page, limit: 20 } : {}),
        ...(statusFilter ? { statut: statusFilter } : statutFilterState ? { statut: statutFilterState } : {}),
        ...(siteFilter ? { site: siteFilter } : {}),
        ...(deptFilter ? { departement: deptFilter } : {}),
        ...(definition.canSearch && submittedQuery ? { search: submittedQuery } : {}),
      },
    }).then((result) => {
      if (active) setPayload(result);
    }).catch((reason: unknown) => {
      if (active) setError(reason instanceof Error ? reason.message : 'Impossible de charger les données.');
    }).finally(() => {
      if (active) setLoading(false);
    });
    return () => { active = false; };
  }, [definition, page, refreshKey, statusFilter, statutFilterState, siteFilter, deptFilter, submittedQuery, token]);

  function submitSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPage(1);
    setSubmittedQuery(query.trim());
  }

  return (
    <div className="module-page">
      {selectedRow && (
        <div className="dialog-backdrop" onClick={() => setSelectedRow(null)}>
          <div className="detail-modal" onClick={(e) => e.stopPropagation()}>
            <div className="dialog-heading">
              <div>
                <h2>Détails — {details.title}</h2>
                <p>Consultez l'ensemble des informations enregistrées</p>
              </div>
              <button className="icon-button dialog-close" onClick={() => setSelectedRow(null)}>
                <X size={18} />
              </button>
            </div>

            {path === '/assets' && (
              <div className="modal-tabs">
                <button
                  type="button"
                  className={`modal-tab-btn ${activeModalTab === 'info' ? 'active' : ''}`}
                  onClick={() => setActiveModalTab('info')}
                >
                  <Laptop size={13} style={{ verticalAlign: -2, marginRight: 4 }} /> Informations & Spécifications
                </button>
                <button
                  type="button"
                  className={`modal-tab-btn ${activeModalTab === 'history' ? 'active' : ''}`}
                  onClick={() => setActiveModalTab('history')}
                >
                  <History size={13} style={{ verticalAlign: -2, marginRight: 4 }} /> Historique & Timeline
                </button>
              </div>
            )}

            {path === '/assets' && activeModalTab === 'history' ? (
              loadingAssetDetail ? (
                <div className="loading-lines"><i /><i /><i /></div>
              ) : (
                <div className="timeline-list">
                  <h4 style={{ margin: '8px 0 4px', fontSize: 12, color: '#334155' }}>Affectations & Utilisateurs</h4>
                  {Array.isArray(assetDetail?.affectations) && assetDetail.affectations.length > 0 ? (
                    (assetDetail.affectations as Array<Record<string, unknown>>).map((aff) => (
                      <div className={`timeline-item ${aff.actif ? 'active' : ''}`} key={String(aff.id)}>
                        <div className="timeline-item-header">
                          <span>{String(aff.utilisateur_nom || 'Utilisateur inconnu')} {Boolean(aff.actif) && <span className="status-badge status-green" style={{ marginLeft: 6 }}>Actuel</span>}</span>
                          <span style={{ fontSize: 10, color: '#64748b' }}>
                            {aff.date_attribution ? new Date(String(aff.date_attribution)).toLocaleDateString('fr-FR') : '—'} 
                            {aff.date_retrait ? ` au ${new Date(String(aff.date_retrait)).toLocaleDateString('fr-FR')}` : (aff.actif ? ' (En cours)' : '')}
                          </span>
                        </div>
                        <div className="timeline-item-sub">
                          <span>📍 {String(aff.site || 'Site non précisé')} · {String(aff.departement || 'Département non précisé')}</span>
                          {Boolean(aff.motif) && <div style={{ marginTop: 2, fontStyle: 'italic' }}>Motif : {String(aff.motif)}</div>}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic' }}>Aucune affectation passée enregistrée.</div>
                  )}

                  <h4 style={{ margin: '14px 0 4px', fontSize: 12, color: '#334155' }}>Tickets & Incidents</h4>
                  {Array.isArray(assetDetail?.tickets) && assetDetail.tickets.length > 0 ? (
                    (assetDetail.tickets as Array<Record<string, unknown>>).map((t) => (
                      <div className="timeline-item ticket" key={String(t.id)}>
                        <div className="timeline-item-header">
                          <span>{t.numero ? `[${String(t.numero)}] ` : ''}{String(t.titre)}</span>
                          <span className={`status-badge ${statusTone(String(t.statut))}`}>{String(t.statut)}</span>
                        </div>
                        <div className="timeline-item-sub">
                          <span>Type: {String(t.type)} · Priorité: {String(t.priorite)} {t.technicien_nom ? `· Tech: ${String(t.technicien_nom)}` : ''}</span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic' }}>Aucun ticket incident enregistré pour ce matériel.</div>
                  )}

                  <h4 style={{ margin: '14px 0 4px', fontSize: 12, color: '#334155' }}>Maintenances & Réparations</h4>
                  {Array.isArray(assetDetail?.maintenances) && assetDetail.maintenances.length > 0 ? (
                    (assetDetail.maintenances as Array<Record<string, unknown>>).map((m) => (
                      <div className="timeline-item maintenance" key={String(m.id)}>
                        <div className="timeline-item-header">
                          <span>{String(m.type)}</span>
                          <span className={`status-badge ${statusTone(String(m.statut))}`}>{String(m.statut)}</span>
                        </div>
                        <div className="timeline-item-sub">
                          <div>{String(m.description || 'Intervention technique')}</div>
                          <span style={{ fontSize: 10, color: '#64748b' }}>
                            Prévue: {m.date_prevue ? new Date(String(m.date_prevue)).toLocaleDateString('fr-FR') : '—'}
                            {m.cout ? ` · Coût: ${Number(m.cout).toLocaleString('fr-FR')} XOF` : ''}
                          </span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic' }}>Aucune maintenance enregistrée.</div>
                  )}
                </div>
              )
            ) : (
              <div className="detail-grid">
                {Object.entries(selectedRow)
                  .filter(([k, v]) => typeof v !== 'object' && v !== null && k !== 'deleted_at')
                  .map(([key, val]) => {
                    let formattedVal: React.ReactNode = String(val);
                    if (key === 'statut' || key.endsWith('.statut')) {
                      const sInfo = formatAssetStatus(String(val));
                      formattedVal = <span className={`status-badge ${sInfo.boxTone ? `status-${sInfo.boxTone}` : 'status-gray'}`}>{sInfo.label}</span>;
                    } else if (key === 'type' || key.endsWith('.type')) {
                      const tInfo = formatAssetType(String(val));
                      formattedVal = tInfo.label;
                    } else if (key === 'priorite' || key.endsWith('.priorite')) {
                      formattedVal = <span className={`status-badge ${priorityBadge(String(val))}`}>{String(val)}</span>;
                    } else if (key.includes('date') && String(val).includes('-')) {
                      try {
                        formattedVal = new Date(String(val)).toLocaleDateString('fr-FR');
                      } catch (_) {}
                    }
                    return (
                      <div className="detail-item" key={key}>
                        <span style={{ textTransform: 'capitalize' }}>{key.replace(/_/g, ' ')}</span>
                        <strong>{formattedVal}</strong>
                      </div>
                    );
                  })}
              </div>
            )}
            <div className="dialog-actions" style={{ marginTop: 24, display: 'flex', justifyContent: 'flex-end', gap: 10, flexWrap: 'wrap' }}>
              {path === '/affectations' && Boolean(selectedRow.id) && (
                <>
                  <button
                    type="button"
                    className="button button-primary"
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                    disabled={downloadingPdfId === Number(selectedRow.id)}
                    onClick={() => {
                      handleDownloadPdf(Number(selectedRow.id), String(selectedRow.asset_tag ?? ''));
                    }}
                  >
                    <Download size={15} />
                    {downloadingPdfId === Number(selectedRow.id) ? 'Génération en cours…' : 'Fiche d’Attribution (PDF)'}
                  </button>
                  <button
                    type="button"
                    className="button button-secondary"
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                    disabled={downloadingPdfId === Number(selectedRow.id)}
                    onClick={() => {
                      void handleDownloadRestitutionPdf(Number(selectedRow.id), String(selectedRow.asset_tag ?? ''));
                    }}
                  >
                    <Download size={15} />
                    {downloadingPdfId === Number(selectedRow.id) ? 'Génération en cours…' : 'PV Restitution (PDF)'}
                  </button>
                </>
              )}
              {path === '/assets' && Boolean(selectedRow.id) && (
                <>
                  <button
                    type="button"
                    className="button button-primary"
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                    disabled={downloadingPdfId === Number(selectedRow.id)}
                    onClick={() => {
                      void handleDownloadAssetPdf(Number(selectedRow.id), String(selectedRow.asset_tag ?? selectedRow['Nom Machine'] ?? selectedRow.id));
                    }}
                  >
                    <Download size={15} />
                    {downloadingPdfId === Number(selectedRow.id) ? 'Génération en cours…' : 'Fiche Technique (PDF)'}
                  </button>
                  <button
                    type="button"
                    className="button button-secondary"
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                    onClick={() => {
                      void handleShowQr(Number(selectedRow.id), String(selectedRow.asset_tag ?? selectedRow['Nom Machine'] ?? selectedRow.id));
                    }}
                  >
                    <QrCode size={15} /> Étiquette QR Code
                  </button>
                </>
              )}
              {canEdit && selectedRow && (
                <button
                  type="button"
                  className="button button-secondary"
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                  onClick={() => {
                    const rowToEdit = selectedRow;
                    setSelectedRow(null);
                    setEditingRow(rowToEdit);
                  }}
                >
                  <Pencil size={15} /> Modifier
                </button>
              )}
              {canDelete && selectedRow && (
                <button
                  type="button"
                  className="button button-danger"
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                  onClick={() => {
                    const rowToDelete = selectedRow;
                    setSelectedRow(null);
                    void deleteRow(rowToDelete);
                  }}
                >
                  <Trash2 size={15} /> Supprimer
                </button>
              )}
              <button className="button button-secondary" onClick={() => setSelectedRow(null)}>
                Fermer
              </button>
            </div>
          </div>
        </div>
      )}
      {qrModalAsset && (
        <div className="dialog-backdrop" onClick={() => setQrModalAsset(null)}>
          <div className="detail-modal" style={{ maxWidth: 440, textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
            <div className="dialog-heading">
              <div>
                <h2>Étiquette d’Inventaire IT</h2>
                <p>Marquage et identification rapide de l’équipement</p>
              </div>
              <button className="icon-button dialog-close" onClick={() => setQrModalAsset(null)}>
                <X size={18} />
              </button>
            </div>

            <div style={{ background: '#fff', border: '2px dashed #94a3b8', borderRadius: 12, padding: 20, margin: '16px 0', color: '#0f172a' }}>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.08em', color: '#475569', textTransform: 'uppercase', marginBottom: 10 }}>
                DIRECTION IT · GESTION DU PARC
              </div>
              <img
                src={qrModalAsset.dataUrl}
                alt={`QR Code ${qrModalAsset.tag}`}
                style={{ width: 175, height: 175, display: 'block', margin: '0 auto', borderRadius: 6 }}
              />
              <div style={{ marginTop: 12, fontSize: 16, fontWeight: 800, color: '#0f172a' }}>
                {qrModalAsset.tag}
              </div>
              <div style={{ fontSize: 12, color: '#475569', marginTop: 3 }}>
                {[qrModalAsset.asset.marque, qrModalAsset.asset.modele].filter(Boolean).join(' ') || String(qrModalAsset.asset.type ?? '').toUpperCase()}
              </div>
              {Boolean(qrModalAsset.asset.serial_number) && (
                <div style={{ fontSize: 11, color: '#64748b', marginTop: 3 }}>
                  S/N : <strong>{String(qrModalAsset.asset.serial_number)}</strong>
                </div>
              )}
              {Boolean(qrModalAsset.asset.site) && (
                <div style={{ fontSize: 11, color: '#0284c7', fontWeight: 600, marginTop: 4 }}>
                  📍 Site : {String(qrModalAsset.asset.site)}
                </div>
              )}
            </div>

            <div className="dialog-actions" style={{ justifyContent: 'center', gap: 10 }}>
              <button
                type="button"
                className="button button-primary"
                style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                onClick={() => window.print()}
              >
                <Printer size={15} /> Imprimer l'étiquette
              </button>
              <a
                className="button button-secondary"
                style={{ display: 'inline-flex', alignItems: 'center', gap: 6, textDecoration: 'none' }}
                href={qrModalAsset.dataUrl}
                download={`QR_${qrModalAsset.tag}.png`}
              >
                <Download size={15} /> Télécharger PNG
              </a>
              <button className="button button-secondary" onClick={() => setQrModalAsset(null)}>
                Fermer
              </button>
            </div>
          </div>
        </div>
      )}
      <BatchQrLabelsModal
        isOpen={showBatchLabels}
        onClose={() => setShowBatchLabels(false)}
        assets={rows}
      />
      <SignaturePadModal
        isOpen={Boolean(signingAff)}
        onClose={() => setSigningAff(null)}
        title="Émargement & Décharge de Matériel IT"
        beneficiaire={signingAff?.user || ''}
        onSave={handleSignedPdf}
      />
      {restitutionItem && (
        <div className="dialog-backdrop" onClick={() => setRestitutionItem(null)}>
          <div className="create-dialog" style={{ maxWidth: 480 }} onClick={(e) => e.stopPropagation()}>
            <div className="dialog-heading">
              <div>
                <h2>Restitution de matériel</h2>
                <p>Clôture de l'affectation et réintégration au stock</p>
              </div>
              <button className="icon-button dialog-close" onClick={() => setRestitutionItem(null)}>
                <X size={18} />
              </button>
            </div>
            <div style={{ marginTop: 16 }}>
              <div style={{ padding: 12, background: '#f8fafc', borderRadius: 8, marginBottom: 14, fontSize: 12, border: '1px solid #e2e8f0' }}>
                <div style={{ color: '#0f172a' }}>Équipement : <strong>{String(restitutionItem.asset_tag ?? restitutionItem['Nom Machine'] ?? restitutionItem.asset_id)}</strong></div>
                <div style={{ marginTop: 4, color: '#0f172a' }}>Collaborateur : <strong>{String(restitutionItem.user_nom ?? restitutionItem.nom ?? restitutionItem.user_id)}</strong></div>
              </div>

              <div className="create-field" style={{ marginBottom: 12 }}>
                <span>Motif de la restitution :</span>
                <select
                  value={restitutionMotif}
                  onChange={(e) => setRestitutionMotif(e.target.value)}
                >
                  <option value="Départ collaborateur / Fin de mission">Départ collaborateur / Fin de mission</option>
                  <option value="Changement de poste / Renouvellement">Changement de poste / Renouvellement</option>
                  <option value="Panne matérielle / Réparation">Panne matérielle / Réparation</option>
                  <option value="Fin de stage / Fin de contrat">Fin de stage / Fin de contrat</option>
                  <option value="Autre motif">Autre motif</option>
                </select>
              </div>

              <div className="create-field" style={{ marginBottom: 16 }}>
                <span>Statut de l'équipement après restitution :</span>
                <select
                  value={restitutionStatut}
                  onChange={(e) => setRestitutionStatut(e.target.value)}
                >
                  <option value="en_stock">En stock (disponible pour réaffectation)</option>
                  <option value="en_maintenance">En maintenance (nécessite réparation)</option>
                  <option value="hors_service">Hors service</option>
                  <option value="reforme">Réformé / Mis au rebut</option>
                </select>
              </div>

              <div className="dialog-actions" style={{ gap: 10 }}>
                <button
                  type="button"
                  className="button button-secondary"
                  onClick={() => setRestitutionItem(null)}
                  disabled={isSubmittingRestitution}
                >
                  Annuler
                </button>
                <button
                  type="button"
                  className="button button-primary"
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
                  onClick={() => void handleConfirmRestitution()}
                  disabled={isSubmittingRestitution}
                >
                  <RotateCcw size={15} />
                  {isSubmittingRestitution ? 'Enregistrement…' : 'Confirmer & Générer PV PDF'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      {createOpen && definition.createFields && (
        <CreateItemDialog
          definition={definition}
          token={token}
          onClose={() => setCreateOpen(false)}
          onCreated={() => {
            setCreateOpen(false);
            setSuccessMessage('Enregistrement créé avec succès.');
            setPage(1);
            setRefreshKey((current) => current + 1);
          }}
        />
      )}
      {editingRow && definition.editFields && (
        <CreateItemDialog
          definition={definition}
          token={token}
          mode="edit"
          initialRecord={editingRow}
          onClose={() => setEditingRow(null)}
          onCreated={() => {
            setEditingRow(null);
            setSuccessMessage('Enregistrement modifié avec succès.');
            setRefreshKey((current) => current + 1);
          }}
        />
      )}
      <div className="page-heading">
        <div><span className="eyebrow">GESTION DU PARC</span><h1>{details.title}</h1><p>{details.subtitle}</p></div>
        <div className="heading-actions">
          {canCreate && <button className="button button-primary" onClick={() => setCreateOpen(true)}><Plus size={15} /> Ajouter</button>}
          {path === '/assets' && (
            <button
              type="button"
              className="button button-secondary"
              onClick={() => setShowBatchLabels(true)}
              title="Générer une planche d'étiquettes QR Code A4 imprimable"
              style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
            >
              <Printer size={15} /> Planche d'étiquettes A4
            </button>
          )}
          <button
            type="button"
            className="button button-secondary"
            onClick={handleExportCsv}
            title="Exporter la liste actuelle en fichier CSV / Excel"
          >
            <FileSpreadsheet size={15} /> Exporter CSV
          </button>
          <button className="button button-secondary" onClick={() => setRefreshKey((current) => current + 1)} disabled={loading}>
            <RefreshCw size={15} /> Actualiser
          </button>
        </div>
      </div>
      <section className="panel data-panel">
        {statusFilter && (
          <div className="active-filter">
            <span>Filtre : <strong>{statusFilter.replace(/_/g, ' ')}</strong></span>
            <Link to="/assets">Effacer le filtre</Link>
          </div>
        )}
        {(path === '/assets' || path === '/affectations') && (
          <div className="filter-bar">
            <div className="filter-group">
              <span className="filter-label">Site :</span>
              <div className="filter-pills">
                {['', 'BOUAKE', 'ABIDJAN', 'BOUAFLE', 'KATIOLA'].map((s) => (
                  <button
                    key={s}
                    type="button"
                    className={`filter-pill ${siteFilter === s ? 'active' : ''}`}
                    onClick={() => { setSiteFilter(s); setPage(1); }}
                  >
                    {s === '' ? 'Tous les sites' : s}
                  </button>
                ))}
              </div>
              <select
                className="filter-select"
                value={['', 'BOUAKE', 'ABIDJAN', 'BOUAFLE', 'KATIOLA'].includes(siteFilter) ? '' : siteFilter}
                onChange={(e) => { setSiteFilter(e.target.value); setPage(1); }}
                title="Autre site"
              >
                <option value="">Autres sites…</option>
                {['AZAGUIE', 'DJEBOA', 'YAMOUSSOUKRO'].map((s) => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>

            <div className="filter-group">
              <span className="filter-label">Département :</span>
              <select
                className="filter-select"
                value={deptFilter}
                onChange={(e) => { setDeptFilter(e.target.value); setPage(1); }}
              >
                <option value="">Tous les départements</option>
                <option value="Direction IT">Direction IT</option>
                <option value="CAJOOMA">CAJOOMA</option>
                <option value="COMPTABILITE">COMPTABILITE</option>
                <option value="Commercial">Commercial</option>
                <option value="RH">Ressources Humaines</option>
                <option value="Logistique">Logistique</option>
                <option value="Direction Générale">Direction Générale</option>
              </select>
            </div>

            {path === '/assets' && (
              <div className="filter-group">
                <span className="filter-label">Statut :</span>
                <select
                  className="filter-select"
                  value={statutFilterState}
                  onChange={(e) => { setStatutFilterState(e.target.value); setPage(1); }}
                >
                  <option value="">Tous les statuts</option>
                  <option value="en_service">En service</option>
                  <option value="en_stock">En stock</option>
                  <option value="en_maintenance">En maintenance</option>
                  <option value="hors_service">Hors service</option>
                  <option value="reforme">Réformé</option>
                </select>
              </div>
            )}

            {(siteFilter || deptFilter || statutFilterState) && (
              <button
                type="button"
                className="clear-filter-btn"
                onClick={() => {
                  setSiteFilter('');
                  setDeptFilter('');
                  setStatutFilterState('');
                  setPage(1);
                }}
              >
                <X size={12} /> Réinitialiser
              </button>
            )}
          </div>
        )}
        <div className="module-toolbar">
          <div className="module-count">
            {loading
              ? 'Chargement…'
              : `${filteredRows.length} résultat${filteredRows.length > 1 ? 's' : ''}${filteredRows.length !== rows.length ? ` (sur ${rows.length})` : ''}`}
          </div>
          {definition.canSearch && (
            <form className="table-search" onSubmit={submitSearch}>
              <Search size={15} />
              <input aria-label={`Rechercher dans ${details.title}`} placeholder="Rechercher…" value={query} onChange={(event) => setQuery(event.target.value)} />
              <button type="submit">Rechercher</button>
            </form>
          )}
        </div>
        {successMessage && <div className="alert alert-success" role="status"><div><strong>Opération réussie</strong><span>{successMessage}</span></div><button className="alert-dismiss" onClick={() => setSuccessMessage('')} aria-label="Fermer">×</button></div>}
        {error && <div className="alert alert-error" role="alert"><div><strong>Erreur de récupération des données</strong><span>{error}</span></div><button className="button button-secondary" onClick={() => setRefreshKey((current) => current + 1)}>Réessayer</button></div>}
        {loading ? <div className="loading-lines"><i /><i /><i /></div> : (
          <div className="table-scroll module-table-scroll">
            <table className="data-table module-table">
              <thead>
                <tr>
                  {definition.columns.map((column) => (
                    <th
                      key={column.key}
                      onClick={() => handleSort(column.key)}
                      className="th-sortable"
                      title="Cliquer pour trier"
                    >
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                        {column.label}
                        <ArrowUpDown size={11} style={{ opacity: sortField === column.key ? 1 : 0.3 }} />
                      </span>
                    </th>
                  ))}
                  <th style={{ width: path === '/affectations' ? 360 : (canEdit || canDelete || path === '/assets' ? 220 : 60), textAlign: 'center' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {sortedRows.map((row, index) => (
                  <tr
                    key={String(row.id ?? row.asset_tag ?? row.numero ?? index)}
                    onClick={() => setSelectedRow(row)}
                    title="Cliquer pour voir la fiche détaillée"
                  >
                    {definition.columns.map((column) => {
                      const value = getPath(row, column.key);
                      const text = cellText(value);
                      let content: React.ReactNode = text;
                      if (column.key === 'statut' || column.key.endsWith('.statut')) {
                        const sInfo = formatAssetStatus(text);
                        content = <span className={`status-badge ${statusTone(text)}`}>{sInfo.label.split(' (')[0]}</span>;
                      } else if (column.key === 'type' || column.key.endsWith('.type')) {
                        const tInfo = formatAssetType(text);
                        const TypeIcon = tInfo.icon;
                        content = (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                            <TypeIcon size={13} style={{ color: '#2563eb', flexShrink: 0 }} />
                            <span>{tInfo.label}</span>
                          </span>
                        );
                      } else if (column.key === 'priorite' || column.key.endsWith('.priorite')) {
                        content = <span className={`status-badge ${priorityBadge(text)}`}>{text}</span>;
                      } else if (column.key === 'asset_tag' || column.key === 'Nom Machine' || column.key === 'nom_machine') {
                        content = (
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                            <div className="pro-icon-box blue" style={{ width: 24, height: 24 }}>
                              <Laptop size={12} />
                            </div>
                            <strong style={{ color: '#0f172a', fontSize: 12 }}>{text}</strong>
                          </div>
                        );
                      }
                      return <td key={column.key}>{content}</td>;
                    })}
                    <td style={{ textAlign: 'center', whiteSpace: 'nowrap' }}>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
                        {path === '/affectations' && (
                          <>
                            <button
                              type="button"
                              className="button button-secondary"
                              style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26 }}
                              title="Télécharger la fiche d'attribution PDF"
                              disabled={downloadingPdfId === Number(row.id)}
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDownloadPdf(Number(row.id), String(row.asset_tag ?? ''));
                              }}
                            >
                              <Download size={12} />
                              {downloadingPdfId === Number(row.id) ? '...' : 'Attribution'}
                            </button>
                            <button
                              type="button"
                              className="button button-secondary"
                              style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26 }}
                              title="Télécharger le PV officiel de restitution et décharge (PDF)"
                              disabled={downloadingPdfId === Number(row.id)}
                              onClick={(e) => {
                                e.stopPropagation();
                                void handleDownloadRestitutionPdf(Number(row.id), String(row.asset_tag ?? ''));
                              }}
                            >
                              <Download size={12} />
                              <span>PV Retour</span>
                            </button>
                            <button
                              type="button"
                              className="button button-secondary"
                              style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26, color: '#0284c7', borderColor: '#bae6fd' }}
                              title="Signer numériquement sur écran tactile et générer la décharge certifiée"
                              onClick={(e) => {
                                e.stopPropagation();
                                const userName = String(row.utilisateur_nom ?? `${row.prenom ?? ''} ${row.nom ?? ''}`.trim() ?? 'Collaborateur');
                                const tag = String(row.asset_tag ?? row.asset_id ?? '');
                                setSigningAff({ id: Number(row.id), tag, user: userName });
                              }}
                            >
                              <PenTool size={12} />
                              <span>Signer</span>
                            </button>
                            {Boolean(row.actif === 1 || row.actif === true || (!row.date_retrait && row.actif !== 0)) && (
                              <button
                                type="button"
                                className="button button-secondary"
                                style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26, color: '#d97706', borderColor: '#fcd34d' }}
                                title="Clôturer cette affectation et restituer l'équipement au stock"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setRestitutionItem(row);
                                }}
                              >
                                <RotateCcw size={12} />
                                <span>Restituer</span>
                              </button>
                            )}
                          </>
                        )}
                        {path === '/assets' && (
                          <>
                            <button
                              type="button"
                              className="button button-secondary"
                              style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26 }}
                              title="Télécharger la fiche technique officielle (PDF)"
                              disabled={downloadingPdfId === Number(row.id)}
                              onClick={(e) => {
                                e.stopPropagation();
                                void handleDownloadAssetPdf(Number(row.id), String(row.asset_tag ?? row['Nom Machine'] ?? row.id));
                              }}
                            >
                              <Download size={12} />
                              <span>{downloadingPdfId === Number(row.id) ? '...' : 'PDF'}</span>
                            </button>
                            <button
                              type="button"
                              className="button button-secondary"
                              style={{ padding: '2px 8px', fontSize: 11, display: 'inline-flex', alignItems: 'center', gap: 4, height: 26 }}
                              title="Générer l'étiquette QR Code"
                              onClick={(e) => {
                                e.stopPropagation();
                                void handleShowQr(Number(row.id), String(row.asset_tag ?? row['Nom Machine'] ?? row.id));
                              }}
                            >
                              <QrCode size={12} />
                              <span>QR</span>
                            </button>
                          </>
                        )}
                        {canEdit && (
                          <button
                            type="button"
                            className="button button-secondary row-action-button"
                            title="Modifier"
                            aria-label={`Modifier ${String(row.asset_tag ?? row.nom ?? row.id)}`}
                            onClick={(event) => {
                              event.stopPropagation();
                              setEditingRow(row);
                            }}
                          >
                            <Pencil size={13} /><span>Modifier</span>
                          </button>
                        )}
                        {canDelete && (
                          <button
                            type="button"
                            className="button button-danger row-action-button"
                            title="Supprimer"
                            aria-label={`Supprimer ${String(row.asset_tag ?? row.nom ?? row.id)}`}
                            onClick={(event) => {
                              event.stopPropagation();
                              void deleteRow(row);
                            }}
                          >
                            <Trash2 size={13} /><span>Supprimer</span>
                          </button>
                        )}
                        <span style={{ color: '#4d65e2', display: 'inline-flex', alignItems: 'center' }} title="Détails">
                          <Eye size={15} />
                        </span>
                      </div>
                    </td>
                  </tr>
                ))}
                {!sortedRows.length && !error && <tr><td colSpan={definition.columns.length + 1}><EmptyState text="Aucun résultat trouvé." /></td></tr>}
              </tbody>
            </table>
          </div>
        )}
        {definition.paginated && <div className="pagination">
          <button className="button button-secondary" disabled={page <= 1 || loading} onClick={() => setPage((current) => Math.max(1, current - 1))}>Précédent</button>
          <span>Page {page}</span>
          <button className="button button-secondary" disabled={!canNextPage || loading} onClick={() => setPage((current) => current + 1)}>Suivant</button>
        </div>}
      </section>
    </div>
  );
}

function CreateItemDialog({
  definition,
  token,
  mode = 'create',
  initialRecord,
  onClose,
  onCreated,
}: {
  definition: ModuleDefinition;
  token: string | null;
  mode?: 'create' | 'edit';
  initialRecord?: Record<string, unknown>;
  onClose: () => void;
  onCreated: () => void;
}) {
  const fields = mode === 'edit' ? definition.editFields ?? [] : definition.createFields ?? [];
  const [values, setValues] = useState<Record<string, string | boolean>>(() => Object.fromEntries(
    fields.map((field) => [
      field.name,
      mode === 'edit' && initialRecord
        ? getEditFieldValue(initialRecord, field)
        : field.type === 'checkbox' ? false : field.type === 'select' ? field.options?.[0] ?? '' : '',
    ]),
  ));
  const [assetOptions, setAssetOptions] = useState<Array<{ id: number; label: string }>>([]);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (mode === 'create' && fields.some((f) => f.name === 'asset_id')) {
      apiRequest<unknown>('/assets?limit=150', { token })
        .then((res) => {
          const list = extractRows(res);
          const opts = list.map((a) => {
            const tag = String(a.asset_tag ?? a['Nom Machine'] ?? a.nom_machine ?? a.id);
            const desc = [a.marque, a.modele].filter(Boolean).join(' ');
            const statut = a.statut ? ` [${a.statut}]` : '';
            return {
              id: Number(a.id),
              label: `${tag}${desc ? ` — ${desc}` : ''}${statut}`,
            };
          });
          setAssetOptions(opts);
        })
        .catch(() => {});
    }
  }, [fields, mode, token]);

  useEffect(() => {
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape' && !saving) onClose();
    }
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [onClose, saving]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    if (mode === 'edit' && (!Number.isInteger(Number(initialRecord?.id)) || Number(initialRecord?.id) <= 0)) {
      setError('Impossible de modifier cet élément : identifiant invalide.');
      return;
    }
    if (mode === 'create' && definition.endpoint === '/users' && Boolean(values.username) !== Boolean(values.password)) {
      setError('Pour créer un accès, renseignez à la fois l’identifiant et le mot de passe.');
      return;
    }
    setSaving(true);
    try {
      const body = fields.reduce<Record<string, string | number | boolean | null>>((result, field) => {
        const value = values[field.name];
        if (field.type === 'checkbox') {
          result[field.name] = Boolean(value);
          return result;
        }
        const text = String(value ?? '').trim();
        if (!text) {
          if (mode === 'edit' && !field.required) result[field.name] = null;
          return result;
        }
        if (field.name === 'role' && !values.username) return result;
        result[field.name] = field.type === 'number' ? Number(text) : text;
        return result;
      }, {});
      if (mode === 'edit' && definition.endpoint === '/affectations' && initialRecord?.user_id) {
        body.user_id = Number(initialRecord.user_id);
      }
      const id = Number(initialRecord?.id);
      await apiRequest<unknown>(mode === 'edit' ? `${definition.endpoint}/${id}` : definition.endpoint, {
        method: mode === 'edit' ? 'PUT' : 'POST',
        token,
        body: definition.wrapAsset ? { asset: body } : body,
      });
      onCreated();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'La création a échoué.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget && !saving) onClose(); }}>
      <section className="create-dialog" role="dialog" aria-modal="true" aria-labelledby="create-dialog-title">
        <div className="dialog-heading">
          <div><span className="eyebrow">{mode === 'edit' ? 'MODIFICATION' : 'NOUVEL ENREGISTREMENT'}</span><h2 id="create-dialog-title">{mode === 'edit' ? `Modifier ${definition.title.toLowerCase()}` : `Ajouter à ${definition.title.toLowerCase()}`}</h2></div>
          <button className="icon-button dialog-close" onClick={onClose} disabled={saving} aria-label="Fermer"><X size={19} /></button>
        </div>
        <form className="create-form" onSubmit={submit}>
          <div className="create-fields">
            {fields.map((field) => (
              <label className={`create-field${field.type === 'textarea' ? ' field-wide' : ''}${field.type === 'checkbox' ? ' checkbox-field' : ''}`} key={field.name}>
                {field.type === 'checkbox' ? (
                  <><input type="checkbox" checked={Boolean(values[field.name])} onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.checked }))} /><span>{field.label}</span></>
                ) : (
                  <>
                    <span>{field.label}{field.required && <i> *</i>}</span>
                    {field.name === 'asset_id' && assetOptions.length > 0 ? (
                      <select
                        required={field.required}
                        value={String(values[field.name] ?? '')}
                        onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))}
                      >
                        <option value="">-- Choisir un équipement ({assetOptions.length} dans le parc) --</option>
                        {assetOptions.map((opt) => (
                          <option key={opt.id} value={opt.id}>
                            {opt.label}
                          </option>
                        ))}
                      </select>
                    ) : field.type === 'textarea' ? (
                      <textarea required={field.required} value={String(values[field.name] ?? '')} placeholder={field.placeholder} onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))} />
                    ) : field.type === 'select' ? (
                      <select required={field.required} value={String(values[field.name] ?? '')} onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))}>
                        {mode === 'edit' && values[field.name] && !field.options?.includes(String(values[field.name])) && (
                          <option value={String(values[field.name])}>{String(values[field.name])}</option>
                        )}
                        {(field.options ?? []).map((option) => <option value={option} key={option}>{option}</option>)}
                      </select>
                    ) : (
                      <input
                        type={field.type ?? 'text'}
                        required={field.required}
                        min={field.type === 'number' ? 0 : undefined}
                        step={field.type === 'number' ? 'any' : undefined}
                        value={String(values[field.name] ?? '')}
                        placeholder={field.placeholder}
                        onChange={(event) => setValues((current) => ({ ...current, [field.name]: event.target.value }))}
                      />
                    )}
                  </>
                )}
              </label>
            ))}
          </div>
          {error && <div className="form-error" role="alert">{error}</div>}
          <div className="dialog-actions">
            <button type="button" className="button button-secondary" onClick={onClose} disabled={saving}>Annuler</button>
            <button className="button button-primary" disabled={saving}>{saving ? <span className="spinner" /> : mode === 'edit' ? <Pencil size={14} /> : <Plus size={14} />}{saving ? 'Enregistrement…' : mode === 'edit' ? 'Enregistrer' : 'Créer'}</button>
          </div>
        </form>
      </section>
    </div>
  );
}

function SearchPage() {
  const { token } = useAuth();
  const [searchParams] = useSearchParams();
  const initialQ = searchParams.get('q') || '';
  const [query, setQuery] = useState(initialQ);
  const [results, setResults] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const categories = [
    ['assets', 'Équipements', '/assets', Laptop],
    ['tickets', 'Tickets & Pannes', '/tickets', Ticket],
    ['maintenances', 'Maintenances', '/maintenances', Settings],
    ['licences', 'Licences', '/licences', ShieldCheck],
    ['wiki', 'Base de connaissances', '/wiki', BookOpen],
  ] as const;

  useEffect(() => {
    const q = searchParams.get('q');
    if (q && q.trim().length >= 2) {
      setQuery(q);
      setLoading(true);
      setError('');
      apiRequest<unknown>('/search', { token, query: { q: q.trim() } })
        .then((res) => setResults(asRecord(res)))
        .catch((reason) => setError(reason instanceof Error ? reason.message : 'La recherche a échoué.'))
        .finally(() => setLoading(false));
    }
  }, [searchParams, token]);

  async function search(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (query.trim().length < 2) {
      setError('Saisissez au moins deux caractères.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      setResults(asRecord(await apiRequest<unknown>('/search', { token, query: { q: query.trim() } })));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'La recherche a échoué.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">GESTION DU PARC</span>
          <h1>Recherche globale</h1>
          <p>Retrouvez un équipement, un ticket, une licence ou une procédure technique.</p>
        </div>
      </div>
      <section className="panel search-panel">
        <form className="global-search" onSubmit={search}>
          <Search size={19} />
          <input
            placeholder="Ex. numéro de série, nom machine, ticket, utilisateur…"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            aria-label="Recherche globale"
          />
          <button className="button button-primary" disabled={loading}>
            {loading ? 'Recherche…' : 'Rechercher'}
          </button>
        </form>
        {error && <div className="alert alert-error" role="alert"><div><strong>Recherche impossible</strong><span>{error}</span></div></div>}
        {loading && <div className="loading-lines"><i /><i /></div>}
        {results && !loading && (
          <div className="search-results">
            {categories.map(([key, title, targetPath, Icon]) => {
              const rows = extractRows(results[key]);
              return (
                <section className="search-category" key={key}>
                  <h2>
                    <Icon size={14} style={{ marginRight: 4, color: '#2563eb' }} />
                    {title}
                    <span>{rows.length}</span>
                  </h2>
                  {rows.length ? (
                    rows.map((row, index) => {
                      const mainText = cellText(row.asset_tag ?? row.numero ?? row.titre ?? row.nom ?? row.nom_machine);
                      const subText = cellText(row.type ?? row.statut ?? row.description ?? row.categorie);
                      return (
                        <Link
                          to={`${targetPath}?search=${encodeURIComponent(mainText)}`}
                          key={String(row.id ?? index)}
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            padding: '8px 10px',
                            borderRadius: 6,
                            background: '#f8fafc',
                            textDecoration: 'none',
                            marginBottom: 6,
                            transition: 'all 0.15s ease',
                            border: '1px solid #e2e8f0',
                          }}
                        >
                          <div style={{ minWidth: 0, overflow: 'hidden' }}>
                            <strong style={{ display: 'block', fontSize: 11, color: '#1e293b', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                              {mainText}
                            </strong>
                            <span style={{ fontSize: 10, color: '#64748b', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                              {subText}
                            </span>
                          </div>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 10, color: '#2563eb', fontWeight: 600, flexShrink: 0, marginLeft: 8 }}>
                            <span>Consulter</span>
                            <ArrowRight size={12} />
                          </div>
                        </Link>
                      );
                    })
                  ) : (
                    <p style={{ fontSize: 11, color: '#94a3b8', fontStyle: 'italic', margin: '8px 0' }}>Aucun résultat dans cette catégorie.</p>
                  )}
                </section>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}

function ReportsPage() {
  const { token } = useAuth();
  const [report, setReport] = useState<Record<string, unknown> | null>(null);
  const [amortissement, setAmortissement] = useState<any>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    apiRequest<Record<string, unknown>>('/dashboard/reports', { token })
      .then((result) => { if (active) setReport(result); })
      .catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : 'Impossible de charger les rapports.'); })
      .finally(() => { if (active) setLoading(false); });

    apiRequest<any>('/dashboard/amortissement', { token })
      .then((data) => { if (active) setAmortissement(data); })
      .catch(() => {});

    return () => { active = false; };
  }, [token]);

  function handleExportAmortissementCsv() {
    if (!amortissement?.items) return;
    const headers = ['Tag Machine', 'Marque', 'Modèle', 'Type', 'Site', 'Date Acquisition', 'Âge (Années)', 'Prix Achat (XOF)', 'VNC Actuelle (XOF)', 'Taux Amorti', 'Statut Fin de Vie'];
    const rows = amortissement.items.map((item: any) => [
      item.asset_tag,
      item.marque,
      item.modele,
      item.type,
      item.site,
      item.date_acquisition,
      item.age_annees,
      item.prix_achat,
      item.vnc,
      `${item.taux_amorti_pct}%`,
      item.est_amorti ? '100% AMORTI (À RENOUVELER)' : 'EN COURS D\'AMORTISSEMENT'
    ]);
    const csv = '\uFEFF' + [headers.join(';'), ...rows.map((r: any[]) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(';'))].join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `Amortissement_Parc_IT_${new Date().getFullYear()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  const typeData = extractRows(report?.assets_by_type);
  const statutData = extractRows(report?.assets_by_statut);
  const licencesData = extractRows(report?.licences_utilisation);
  const consommablesData = extractRows(report?.consommables_stock);
  const maintenanceData = extractRows(report?.maintenances_costs);
  const totalMaintenanceCost = maintenanceData.reduce((sum, item) => sum + Number(item.total_cout || 0), 0);
  const maxMaintCost = Math.max(...maintenanceData.map((d) => Number(d.total_cout || 0)), 1);

  const maxType = Math.max(...typeData.map((d) => Number(d.count || 0)), 1);
  const maxStatut = Math.max(...statutData.map((d) => Number(d.count || 0)), 1);
  const statusCount = (status: string) => statutData
    .filter((item) => String(item.statut ?? '').toLowerCase() === status)
    .reduce((sum, item) => sum + Number(item.count || 0), 0);
  const reportCards = [
    { label: 'Équipements recensés', value: typeData.reduce((sum, item) => sum + Number(item.count || 0), 0), icon: Laptop, tone: 'blue', note: 'Total de l’inventaire', to: '/assets' },
    { label: 'Stocks critiques', value: consommablesData.filter((item) => Number(item.quantite || 0) <= Number(item.seuil_alerte || 0)).length, icon: CircleAlert, tone: 'orange', note: 'Consommables à réapprovisionner', to: '/consommables' },
    { label: 'En service', value: statusCount('en_service'), icon: Activity, tone: 'green', note: 'Équipements opérationnels', to: '/assets?statut=en_service' },
    { label: 'En maintenance', value: statusCount('en_maintenance'), icon: Settings, tone: 'yellow', note: 'À suivre', to: '/assets?statut=en_maintenance' },
  ];

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ANALYSE DU PARC</span>
          <h1>Rapports & Indicateurs Clés</h1>
          <p>Indicateurs décisionnels et suivi de conformité du parc informatique.</p>
        </div>
        <div className="heading-actions">
          <button
            type="button"
            className="button button-secondary"
            onClick={() => window.print()}
            title="Imprimer ou exporter en PDF ce rapport d'audit"
          >
            <Printer size={15} /> Imprimer le Rapport
          </button>
        </div>
      </div>

      {error && <div className="alert alert-error" role="alert"><div><strong>Erreur de récupération des données</strong><span>{error}</span></div></div>}

      {loading ? (
        <section className="panel"><div className="loading-lines"><i /><i /><i /></div></section>
      ) : (
        <>
        <div className="stats-grid report-kpi-grid">
          {reportCards.map(({ label, value, icon: Icon, tone, note, to }) => (
            <Link className={`stat-card stat-card-link tone-${tone}`} key={label} to={to} aria-label={`${label} : consulter les données`}>
              <div className={`stat-icon ${tone}`}><Icon size={19} /></div>
              <div className="stat-label">{label}</div>
              <div className="stat-value">{value.toLocaleString('fr-FR')}</div>
              <div className="stat-note">{note}</div>
              <div className="stat-link-hint">Consulter <ArrowRight size={13} /></div>
            </Link>
          ))}
        </div>
        <div className="dashboard-columns">
          {/* Équipements par Statut */}
          <section className="panel pro-card">
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 14, fontWeight: 700 }}>État de Santé du Parc (Statuts)</h2>
                <p style={{ fontSize: 11 }}>Répartition par condition opérationnelle</p>
              </div>
              <div className="panel-heading-icon green"><Activity size={18} /></div>
            </div>
            <div className="pro-bar-list">
              {statutData.map((item, idx) => {
                const count = Number(item.count || 0);
                const pct = Math.round((count / maxStatut) * 100);
                const info = formatAssetStatus(String(item.statut || ''));
                const Icon = info.icon;
                return (
                  <Link
                    to={`/assets?statut=${encodeURIComponent(String(item.statut || ''))}`}
                    className="pro-dashboard-row"
                    key={idx}
                    title={`Voir les équipements : ${info.label}`}
                  >
                    <div className="pro-row-top">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <div className={`pro-icon-box ${info.boxTone}`}>
                          <Icon size={14} />
                        </div>
                        <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>
                          {info.label}
                        </span>
                      </div>
                      <div className="pro-metric-badge">
                        <strong>{count} machine{count > 1 ? 's' : ''}</strong>
                        <span style={{ color: '#94a3b8', fontSize: 10, marginLeft: 4 }}>({pct}%)</span>
                      </div>
                    </div>
                    <div className="pro-bar-track">
                      <span style={{ width: `${pct}%`, background: info.gradient }} />
                    </div>
                  </Link>
                );
              })}
              {!statutData.length && <EmptyState text="Aucune donnée de statut." />}
            </div>
          </section>

          {/* Types d'équipements */}
          <section className="panel pro-card">
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 14, fontWeight: 700 }}>Parc par Type de Matériel</h2>
                <p style={{ fontSize: 11 }}>Volume par catégorie de poste</p>
              </div>
              <div className="panel-heading-icon"><Laptop size={18} /></div>
            </div>
            <div className="pro-bar-list">
              {typeData.map((item, idx) => {
                const count = Number(item.count || 0);
                const pct = Math.round((count / maxType) * 100);
                const info = formatAssetType(String(item.type || ''));
                const Icon = info.icon;
                return (
                  <Link
                    to={`/assets?search=${encodeURIComponent(String(item.type || ''))}`}
                    className="pro-dashboard-row"
                    key={idx}
                    title={`Voir les ${info.label}`}
                  >
                    <div className="pro-row-top">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                        <div className="pro-icon-box blue">
                          <Icon size={14} />
                        </div>
                        <span style={{ fontWeight: 600, fontSize: 12, color: '#1e293b' }}>
                          {info.label}
                        </span>
                      </div>
                      <div className="pro-metric-badge">
                        <strong>{count} unité{count > 1 ? 's' : ''}</strong>
                        <span style={{ color: '#94a3b8', fontSize: 10, marginLeft: 4 }}>({pct}%)</span>
                      </div>
                    </div>
                    <div className="pro-bar-track">
                      <span style={{ width: `${pct}%`, background: 'linear-gradient(90deg, #3b82f6 0%, #6366f1 100%)' }} />
                    </div>
                  </Link>
                );
              })}
              {!typeData.length && <EmptyState text="Aucun équipement recensé." />}
            </div>
          </section>

          {/* Utilisation des Licences */}
          <section className="panel pro-card" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 14, fontWeight: 700 }}>Taux d'Utilisation des Licences Logicielles</h2>
                <p style={{ fontSize: 11 }}>Attributions actuelles par rapport aux quotas achetés</p>
              </div>
              <div className="panel-heading-icon green"><ShieldCheck size={18} /></div>
            </div>
            <div className="table-scroll" style={{ marginTop: 16 }}>
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Logiciel</th>
                    <th>Éditeur</th>
                    <th>Postes attribués</th>
                    <th>Quota Max</th>
                    <th>Taux d'utilisation</th>
                  </tr>
                </thead>
                <tbody>
                  {licencesData.map((lic, idx) => {
                    const quota = Number(lic.quota_max || 0);
                    const alloc = Number(lic.allocated || 0);
                    const pct = quota > 0 ? Math.min(100, Math.round((alloc / quota) * 100)) : 0;
                    const grad =
                      pct > 90
                        ? 'linear-gradient(90deg, #ef4444, #dc2626)'
                        : pct > 75
                        ? 'linear-gradient(90deg, #f59e0b, #d97706)'
                        : 'linear-gradient(90deg, #10b981, #059669)';
                    return (
                      <tr key={idx}>
                        <td>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                            <div className="pro-icon-box purple" style={{ width: 24, height: 24 }}>
                              <ShieldCheck size={13} />
                            </div>
                            <strong>{String(lic.nom)}</strong>
                          </div>
                        </td>
                        <td>{String(lic.editeur || '—')}</td>
                        <td><span style={{ fontWeight: 700 }}>{alloc}</span> poste{alloc > 1 ? 's' : ''}</td>
                        <td>{quota || 'Illimité'}</td>
                        <td style={{ minWidth: 160 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <div className="pro-bar-track" style={{ flex: 1 }}>
                              <span style={{ width: `${pct}%`, background: grad }} />
                            </div>
                            <span style={{ fontSize: 11, fontWeight: 700, minWidth: 35 }}>{pct}%</span>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {!licencesData.length && <tr><td colSpan={5}><EmptyState text="Aucune licence renseignée." /></td></tr>}
                </tbody>
              </table>
            </div>
          </section>

          {/* Alertes Consommables */}
          <section className="panel pro-card" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 14, fontWeight: 700 }}>Niveaux de Stocks Consommables</h2>
                <p style={{ fontSize: 11 }}>Surveillance des consommables par rapport au seuil critique</p>
              </div>
              <div className="panel-heading-icon"><Package size={18} /></div>
            </div>
            <div className="table-scroll" style={{ marginTop: 16 }}>
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Consommable</th>
                    <th>Quantité en stock</th>
                    <th>Seuil d'alerte</th>
                    <th>État du stock</th>
                  </tr>
                </thead>
                <tbody>
                  {consommablesData.map((item, idx) => {
                    const qte = Number(item.quantite || 0);
                    const seuil = Number(item.seuil_alerte || 0);
                    const isLow = qte <= seuil;
                    return (
                      <tr key={idx}>
                        <td>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                            <div className={`pro-icon-box ${isLow ? 'red' : 'green'}`} style={{ width: 24, height: 24 }}>
                              <Package size={13} />
                            </div>
                            <strong>{String(item.nom)}</strong>
                          </div>
                        </td>
                        <td><span style={{ fontSize: 13, fontWeight: 700, color: isLow ? '#dc2626' : '#0f172a' }}>{qte} unité{qte > 1 ? 's' : ''}</span></td>
                        <td>{seuil} unité{seuil > 1 ? 's' : ''}</td>
                        <td>
                          <span className={`status-badge ${isLow ? 'status-red' : 'status-green'}`} style={{ fontSize: 10, padding: '3px 8px' }}>
                            {isLow ? '⚠️ Stock critique' : '✅ Stock suffisant'}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                  {!consommablesData.length && <tr><td colSpan={4}><EmptyState text="Aucun consommable enregistré." /></td></tr>}
                </tbody>
              </table>
            </div>
          </section>

          {/* Suivi Budgétaire des Maintenances */}
          <section className="panel" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2>Suivi Budgétaire des Maintenances & Réparations</h2>
                <p>Dépenses cumulées d'intervention technique par mois</p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <span style={{ fontSize: 10, color: '#64748b', display: 'block', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Budget Global Investi</span>
                <strong style={{ fontSize: 16, color: '#2563eb' }}>{totalMaintenanceCost.toLocaleString('fr-FR')} XOF</strong>
              </div>
            </div>
            {maintenanceData.length > 0 ? (
              <div className="table-scroll" style={{ marginTop: 16 }}>
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Période (Mois)</th>
                      <th>Nombre d'interventions</th>
                      <th>Coût Total (XOF)</th>
                      <th>Intensité Budgétaire</th>
                    </tr>
                  </thead>
                  <tbody>
                    {maintenanceData.map((m, idx) => {
                      const cost = Number(m.total_cout || 0);
                      const pct = Math.round((cost / maxMaintCost) * 100);
                      return (
                        <tr key={idx}>
                          <td><strong>{String(m.mois)}</strong></td>
                          <td>{Number(m.count || 0)} intervention{Number(m.count || 0) > 1 ? 's' : ''}</td>
                          <td><strong style={{ color: '#0f172a' }}>{cost.toLocaleString('fr-FR')} XOF</strong></td>
                          <td style={{ minWidth: 140 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <div className="bar-track" style={{ flex: 1 }}>
                                <span style={{ width: `${pct}%`, background: '#8b5cf6' }} />
                              </div>
                              <span style={{ fontSize: 10, fontWeight: 700 }}>{pct}%</span>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            ) : (
              <div style={{ padding: '24px 0', textAlign: 'center', color: '#94a3b8', fontSize: 11, fontStyle: 'italic' }}>
                Aucune intervention de maintenance clôturée avec coût sur la période.
              </div>
            )}
          </section>

          {/* Pilotage Financier, Amortissement & Budget N+1 */}
          <section className="panel pro-card" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2 style={{ fontSize: 15, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Coins size={18} color="#059669" /> Pilotage Financier, Amortissement & Budget N+1
                </h2>
                <p style={{ fontSize: 11 }}>Calcul de dépréciation linéaire (36 mois) et projection budgétaire de renouvellement</p>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  type="button"
                  className="button button-secondary"
                  onClick={handleExportAmortissementCsv}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12 }}
                >
                  <FileSpreadsheet size={14} /> Grand Livre Amortissement (CSV)
                </button>
              </div>
            </div>

            {amortissement && (
              <>
                <div className="finance-kpi-grid" style={{ marginTop: 16 }}>
                  <div className="finance-card">
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Valeur d'Acquisition Initiale</span>
                    <div className="finance-amount" style={{ color: '#0284c7' }}>
                      {Number(amortissement.total_acquisition || 0).toLocaleString('fr-FR')} XOF
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>Investissement matériel total</span>
                  </div>

                  <div className="finance-card">
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Valeur Nette Comptable (VNC)</span>
                    <div className="finance-amount" style={{ color: '#16a34a' }}>
                      {Number(amortissement.total_vnc || 0).toLocaleString('fr-FR')} XOF
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>Actifs non encore dépréciés</span>
                  </div>

                  <div className="finance-card">
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Matériels 100% Amortis</span>
                    <div className="finance-amount" style={{ color: '#d97706' }}>
                      {amortissement.nb_machines_amorties} / {amortissement.nb_machines_total}
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>Âge moyen : {amortissement.age_moyen_annees} ans</span>
                  </div>

                  <div className="finance-card">
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>Budget Prévisionnel N+1</span>
                    <div className="finance-amount" style={{ color: '#dc2626' }}>
                      {Number(amortissement.budget_previsionnel_n1 || 0).toLocaleString('fr-FR')} XOF
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>Coût de remplacement du parc amorti</span>
                  </div>
                </div>

                {/* Pyramide des âges et progression globale */}
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16, marginTop: 12 }}>
                  <div style={{ background: '#f8fafc', padding: 16, borderRadius: 12, border: '1px solid #e2e8f0' }}>
                    <h3 style={{ fontSize: 12, fontWeight: 700, margin: 0, color: '#334155' }}>Taux Global d'Amortissement du Parc</h3>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '12px 0 6px' }}>
                      <div className="pro-bar-track" style={{ flex: 1, height: 14 }}>
                        <span style={{ width: `${amortissement.taux_global_amorti_pct}%`, background: 'linear-gradient(90deg, #3b82f6, #f59e0b, #ef4444)' }} />
                      </div>
                      <span style={{ fontSize: 15, fontWeight: 800 }}>{amortissement.taux_global_amorti_pct}%</span>
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>Pourcentage de la valeur d'actif déjà amortie</span>
                  </div>

                  <div style={{ background: '#f8fafc', padding: 16, borderRadius: 12, border: '1px solid #e2e8f0' }}>
                    <h3 style={{ fontSize: 12, fontWeight: 700, margin: 0, color: '#334155' }}>Répartition par Tranche d'Âge</h3>
                    <div className="finance-age-pyramid">
                      <div className="finance-pyramid-row">
                        <span className="finance-pyramid-label">&lt; 1 an (Neuf) :</span>
                        <div className="finance-pyramid-bar-bg">
                          <div className="finance-pyramid-bar-fill" style={{ width: `${(amortissement.distribution_age.moins_1_an / (amortissement.nb_machines_total || 1)) * 100}%`, background: '#22c55e' }} />
                        </div>
                        <span style={{ fontSize: 11, fontWeight: 700 }}>{amortissement.distribution_age.moins_1_an}</span>
                      </div>
                      <div className="finance-pyramid-row">
                        <span className="finance-pyramid-label">1 à 2 ans :</span>
                        <div className="finance-pyramid-bar-bg">
                          <div className="finance-pyramid-bar-fill" style={{ width: `${(amortissement.distribution_age.entre_1_2_ans / (amortissement.nb_machines_total || 1)) * 100}%`, background: '#3b82f6' }} />
                        </div>
                        <span style={{ fontSize: 11, fontWeight: 700 }}>{amortissement.distribution_age.entre_1_2_ans}</span>
                      </div>
                      <div className="finance-pyramid-row">
                        <span className="finance-pyramid-label">2 à 3 ans :</span>
                        <div className="finance-pyramid-bar-bg">
                          <div className="finance-pyramid-bar-fill" style={{ width: `${(amortissement.distribution_age.entre_2_3_ans / (amortissement.nb_machines_total || 1)) * 100}%`, background: '#f59e0b' }} />
                        </div>
                        <span style={{ fontSize: 11, fontWeight: 700 }}>{amortissement.distribution_age.entre_2_3_ans}</span>
                      </div>
                      <div className="finance-pyramid-row">
                        <span className="finance-pyramid-label">&gt; 3 ans (Amorti) :</span>
                        <div className="finance-pyramid-bar-bg">
                          <div className="finance-pyramid-bar-fill" style={{ width: `${(amortissement.distribution_age.plus_3_ans / (amortissement.nb_machines_total || 1)) * 100}%`, background: '#ef4444' }} />
                        </div>
                        <span style={{ fontSize: 11, fontWeight: 700 }}>{amortissement.distribution_age.plus_3_ans}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </>
            )}
          </section>
        </div>
        </>
      )}
    </div>
  );
}

function ImportExportPage() {
  const { token, user } = useAuth();
  const canImport = (user?.role ?? '').toLowerCase() === 'admin';
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function importFile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const form = new FormData();
      form.append('file', file);
      const result = await apiRequest<Record<string, unknown>>('/importexport/import/excel', {
        method: 'POST',
        token,
        body: form,
      });
      setMessage(`Import terminé : ${cellText(result.created)} créés, ${cellText(result.updated)} mis à jour.`);
      setFile(null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Import impossible.');
    } finally {
      setBusy(false);
    }
  }

  async function exportFile() {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const blob = await apiDownload('/importexport/export/excel', { token });
      const url = URL.createObjectURL(blob);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = 'inventaire-parc.xlsx';
      anchor.click();
      URL.revokeObjectURL(url);
      setMessage('Export téléchargé.');
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Export impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="page-heading"><div><span className="eyebrow">DONNÉES DU PARC</span><h1>Import / Export</h1><p>Importez une feuille de calcul ou téléchargez l’inventaire.</p></div></div>
      {(error || message) && <div className={`alert ${error ? 'alert-error' : 'alert-success'}`} role={error ? 'alert' : 'status'}><div><strong>{error ? 'Opération impossible' : 'Opération réussie'}</strong><span>{error || message}</span></div>{error && <CircleAlert size={18} />}</div>}
      <div className="transfer-grid">
        {canImport && <section className="panel transfer-card">
          <div className="transfer-icon"><FileUp size={21} /></div><h2>Importer des équipements</h2>
          <p>Choisissez un fichier Excel ou CSV contenant les données du parc.</p>
          <form onSubmit={importFile}>
            <label className="file-picker">
              <input type="file" accept=".xlsx,.xls,.csv" onChange={(event) => setFile(event.target.files?.[0] ?? null)} />
              <span>{file ? file.name : 'Sélectionner un fichier'}</span>
            </label>
            <button className="button button-primary" disabled={!file || busy}>{busy ? 'Traitement…' : 'Importer'}</button>
          </form>
        </section>}
        <section className="panel transfer-card">
          <div className="transfer-icon green"><Download size={21} /></div><h2>Exporter l’inventaire</h2>
          <p>Téléchargez une copie Excel des équipements recensés.</p>
          <button className="button button-secondary" disabled={busy} onClick={() => void exportFile()}><ArrowDownToLine size={15} /> {busy ? 'Préparation…' : 'Télécharger Excel'}</button>
        </section>
      </div>
      <p className="transfer-note"><CircleAlert size={15} /> L’import peut créer de nouveaux équipements ou mettre à jour des références existantes.</p>
    </div>
  );
}

function ProfilePage() {
  const { user, logout } = useAuth();
  const fullName = [user?.prenom, user?.nom].filter(Boolean).join(' ') || user?.username || 'Utilisateur';
  return (
    <div>
      <div className="page-heading"><div><span className="eyebrow">COMPTE</span><h1>Mon profil</h1><p>Informations de votre compte connecté.</p></div></div>
      <section className="panel profile-card">
        <div className="avatar profile-avatar">{initials(fullName, user?.username)}</div>
        <div className="profile-info"><h2>{fullName}</h2><p>{user?.email || 'Aucune adresse e-mail renseignée'}</p><span className="status-badge status-blue">{roleLabel((user?.role ?? 'lecteur').toLowerCase())}</span></div>
        <button className="button button-secondary" onClick={() => void logout()}><LogOut size={15} /> Se déconnecter</button>
      </section>
    </div>
  );
}

function NotFoundPage() {
  return <div className="not-found"><LifeBuoy size={26} /><h1>Page introuvable</h1><Link to="/">Retour au tableau de bord</Link></div>;
}

function ProtectedApp() {
  const { user } = useAuth();
  const location = useLocation();
  if (!user) return <Navigate to="/login" state={{ from: location }} replace />;
  return <AppLayout />;
}

export function App() {
  const { user } = useAuth();
  return (
    <Routes>
      <Route path="/login" element={user ? <Navigate to="/" replace /> : <LoginPage />} />
      <Route path="/*" element={<ProtectedApp />} />
    </Routes>
  );
}
