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
  type LucideIcon,
} from 'lucide-react';
import { Link, Navigate, NavLink, Route, Routes, useLocation } from 'react-router-dom';
import { apiDownload, apiRequest } from './api';
import { useAuth } from './auth';

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
  },
  '/licences': {
    title: 'Licences', subtitle: 'Logiciels et abonnements', endpoint: '/licences', canSearch: true,
    columns: [
      { key: 'nom', label: 'Logiciel' }, { key: 'editeur', label: 'Éditeur' },
      { key: 'quota_max', label: 'Quota' }, { key: 'date_expiration', label: 'Expiration' },
      { key: 'cout', label: 'Coût' },
    ],
    adminOnlyCreate: true,
    createFields: [
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
  { label: 'Inventaire du parc', path: '/assets', icon: Laptop },
  { label: 'Affectations', path: '/affectations', icon: ArrowLeftRight },
  { label: 'Tickets IT', path: '/tickets', icon: Ticket },
  { label: 'Licences', path: '/licences', icon: ShieldCheck },
  { label: 'Consommables', path: '/consommables', icon: Package },
  { label: 'Maintenances', path: '/maintenances', icon: Activity },
  { label: 'Base de connaissances', path: '/wiki', icon: BookOpen },
  { label: 'Gestion des Accès', path: '/users', icon: Users },
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
  const { user, logout } = useAuth();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const title = location.pathname === '/' ? 'Tableau de bord' : pageTitles[location.pathname]?.title ?? 'Mon profil';
  const displayName = [user?.prenom, user?.nom].filter(Boolean).join(' ') || user?.username || 'Utilisateur';
  const role = (user?.role ?? 'lecteur').toLowerCase();
  const visibleNavigation = navigation.filter((item) => {
    if (item.path === '/users' || item.path === '/licences' || item.path === '/import-export') {
      return role === 'admin' || role === 'technicien';
    }
    return true;
  });

  const [darkMode, setDarkMode] = useState<boolean>(() => {
    return localStorage.getItem('parc-it-theme') === 'dark';
  });

  useEffect(() => {
    if (darkMode) {
      document.documentElement.setAttribute('data-theme', 'dark');
      localStorage.setItem('parc-it-theme', 'dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
      localStorage.setItem('parc-it-theme', 'light');
    }
  }, [darkMode]);

  return (
    <div className="app-shell">
      {mobileMenuOpen && <button className="mobile-backdrop" aria-label="Fermer le menu" onClick={() => setMobileMenuOpen(false)} />}
      <aside className={`sidebar ${mobileMenuOpen ? 'sidebar-open' : ''}`}>
        <Link className="brand" to="/">
          <div className="brand-mark"><Boxes size={21} /></div>
          <div className="brand-text"><strong>IT PARC</strong><span>Bouaké · Direction IT</span></div>
        </Link>
        <div className="sidebar-section-label">ESPACE DE TRAVAIL</div>
        <nav className="side-nav" aria-label="Navigation principale">
          {visibleNavigation.map(({ label, path, icon: Icon }) => (
            <NavLink key={path} to={path} end={path === '/'} className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}>
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
            <button
              className="theme-toggle-btn"
              onClick={() => setDarkMode(!darkMode)}
              title={darkMode ? 'Passer en mode clair' : 'Passer en mode sombre'}
              aria-label="Basculer le thème"
            >
              {darkMode ? <Sun size={17} /> : <Moon size={17} />}
            </button>
            <span className="environment-pill"><span /> En ligne</span>
            <Link to="/search" className="icon-button" title="Recherche rapide" aria-label="Recherche">
              <Search size={18} />
            </Link>
            <div className="icon-button notification-button" aria-hidden="true"><Bell size={19} /></div>
            <Link to="/profile" className="topbar-user" title="Voir mon profil">
              <div className="avatar avatar-small">{initials(displayName, user?.username)}</div>
              <ChevronDown size={15} />
            </Link>
          </div>
        </header>
        <main className="page-content">
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            {Object.keys(modules).map((path) => (
              <Route key={path} path={path} element={<ModulePage path={path} />} />
            ))}
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
    { label: 'Équipements recensés', value: total, icon: Laptop, tone: 'blue', note: 'Total du parc' },
    { label: 'En service', value: stats?.totaux?.en_service ?? 0, icon: Activity, tone: 'green', note: 'Équipements actifs' },
    { label: 'En maintenance', value: stats?.totaux?.en_maintenance ?? 0, icon: Settings, tone: 'amber', note: 'Suivi en cours' },
    { label: 'Alertes de sécurité', value: stats?.non_conformes ?? 0, icon: ShieldCheck, tone: 'red', note: 'À vérifier' },
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

      <div className="stats-grid">
        {cards.map(({ label, value, icon: Icon, tone, note }) => (
          <article className="stat-card" key={label}>
            <div className={`stat-icon ${tone}`}><Icon size={19} /></div>
            <div className="stat-label">{label}</div>
            <div className="stat-value">{loading ? <span className="skeleton-number" /> : value.toLocaleString('fr-FR')}</div>
            <div className="stat-note">{note}</div>
          </article>
        ))}
      </div>

      <div className="dashboard-columns">
        <section className="panel">
          <div className="panel-heading">
            <div><h2>Répartition du parc</h2><p>Équipements par catégorie</p></div>
            <div className="panel-heading-icon"><Boxes size={18} /></div>
          </div>
          {loading ? <div className="loading-lines"><i /><i /><i /></div> : (
            <div className="bar-list">
              {(stats?.par_type ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                return (
                  <div className="bar-item" key={`${item.type}-${index}`}>
                    <div className="bar-item-top"><span>{item.type}</span><strong>{item.count}</strong></div>
                    <div className="bar-track"><span style={{ width: `${(item.count / max) * 100}%` }} /></div>
                  </div>
                );
              })}
              {!stats?.par_type?.length && <EmptyState text="Aucune donnée de répartition disponible." />}
            </div>
          )}
        </section>
        <section className="panel">
          <div className="panel-heading">
            <div><h2>Conformité de sécurité</h2><p>État des protections du parc</p></div>
            <div className="panel-heading-icon green"><ShieldCheck size={18} /></div>
          </div>
          <div className="compliance-score">
            <div className="score-number">{loading ? '—' : `${Math.round(stats?.securite?.score_conformite ?? 0)}%`}</div>
            <div><strong>Score de conformité</strong><span>Basé sur les équipements suivis</span></div>
          </div>
          <div className="compliance-list">
            <ComplianceRow label="Microsoft Defender" value={stats?.securite?.defender_ok} total={stats?.securite?.total_avec_securite} />
            <ComplianceRow label="BitLocker" value={stats?.securite?.bitlocker_ok} total={stats?.securite?.total_avec_securite} />
            <ComplianceRow label="Microsoft Intune" value={stats?.securite?.intune_ok} total={stats?.securite?.total_avec_securite} />
          </div>
        </section>
      </div>

      <div className="dashboard-columns" style={{ marginTop: 16 }}>
        <section className="panel">
          <div className="panel-heading">
            <div><h2>Répartition par site</h2><p>Implantation géographique des machines</p></div>
            <div className="panel-heading-icon"><Building2 size={18} /></div>
          </div>
          {loading ? <div className="loading-lines"><i /><i /><i /></div> : (
            <div className="bar-list">
              {(stats?.par_site ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                return (
                  <div className="bar-item" key={`${item.site}-${index}`}>
                    <div className="bar-item-top"><span>{item.site}</span><strong>{item.count} machine{item.count > 1 ? 's' : ''}</strong></div>
                    <div className="bar-track"><span style={{ width: `${(item.count / max) * 100}%`, background: '#3b82f6' }} /></div>
                  </div>
                );
              })}
              {!stats?.par_site?.length && <EmptyState text="Aucune donnée de site disponible." />}
            </div>
          )}
        </section>
        <section className="panel">
          <div className="panel-heading">
            <div><h2>Répartition par département</h2><p>Direction et services utilisateurs</p></div>
            <div className="panel-heading-icon green"><PieChart size={18} /></div>
          </div>
          {loading ? <div className="loading-lines"><i /><i /><i /></div> : (
            <div className="bar-list">
              {(stats?.par_departement ?? []).slice(0, 6).map((item, index, list) => {
                const max = Math.max(...list.map((entry) => entry.count), 1);
                return (
                  <div className="bar-item" key={`${item.departement}-${index}`}>
                    <div className="bar-item-top"><span>{item.departement}</span><strong>{item.count} machine{item.count > 1 ? 's' : ''}</strong></div>
                    <div className="bar-track"><span className="green-fill" style={{ width: `${(item.count / max) * 100}%` }} /></div>
                  </div>
                );
              })}
              {!stats?.par_departement?.length && <EmptyState text="Aucune donnée de département disponible." />}
            </div>
          )}
        </section>
      </div>

      <section className="panel recent-panel">
        <div className="panel-heading">
          <div><h2>Équipements récemment ajoutés</h2><p>Dernières entrées de l’inventaire</p></div>
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

function ComplianceRow({ label, value = 0, total = 0 }: { label: string; value?: number; total?: number }) {
  const percent = total ? Math.min(100, Math.round((value / total) * 100)) : 0;
  return (
    <div className="compliance-row">
      <div><span>{label}</span><strong>{percent}%</strong></div>
      <div className="bar-track"><span className="green-fill" style={{ width: `${percent}%` }} /></div>
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
  const [payload, setPayload] = useState<unknown>(null);
  const [query, setQuery] = useState('');
  const [submittedQuery, setSubmittedQuery] = useState('');
  const [page, setPage] = useState(1);
  const [refreshKey, setRefreshKey] = useState(0);
  const [selectedRow, setSelectedRow] = useState<Record<string, unknown> | null>(null);
  const [sortField, setSortField] = useState<string | null>(null);
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  const rows = useMemo(() => extractRows(payload), [payload]);
  const sortedRows = useMemo(() => {
    if (!sortField) return rows;
    return [...rows].sort((a, b) => {
      const valA = String(getPath(a, sortField) ?? '').toLowerCase();
      const valB = String(getPath(b, sortField) ?? '').toLowerCase();
      if (valA < valB) return sortOrder === 'asc' ? -1 : 1;
      if (valA > valB) return sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  }, [rows, sortField, sortOrder]);

  function handleSort(key: string) {
    if (sortField === key) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(key);
      setSortOrder('asc');
    }
  }
  const [createOpen, setCreateOpen] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [downloadingPdfId, setDownloadingPdfId] = useState<number | null>(null);

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

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError('');
    apiRequest<unknown>(definition.endpoint, {
      token,
      query: {
        ...(definition.paginated ? { page, limit: 20 } : {}),
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
  }, [definition, page, refreshKey, submittedQuery, token]);

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
            <div className="detail-grid">
              {Object.entries(selectedRow)
                .filter(([k, v]) => typeof v !== 'object' && v !== null && k !== 'deleted_at')
                .map(([key, val]) => (
                  <div className="detail-item" key={key}>
                    <span>{key.replace(/_/g, ' ')}</span>
                    <strong>{String(val)}</strong>
                  </div>
                ))}
            </div>
            <div className="dialog-actions" style={{ marginTop: 24, display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              {path === '/affectations' && Boolean(selectedRow.id) && (
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
                  {downloadingPdfId === Number(selectedRow.id) ? 'Génération en cours…' : 'Télécharger Fiche d’Attribution (PDF)'}
                </button>
              )}
              <button className="button button-secondary" onClick={() => setSelectedRow(null)}>
                Fermer
              </button>
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
      <div className="page-heading">
        <div><span className="eyebrow">GESTION DU PARC</span><h1>{details.title}</h1><p>{details.subtitle}</p></div>
        <div className="heading-actions">
          {canCreate && <button className="button button-primary" onClick={() => setCreateOpen(true)}><Plus size={15} /> Ajouter</button>}
          <button className="button button-secondary" onClick={() => setRefreshKey((current) => current + 1)} disabled={loading}>
            <RefreshCw size={15} /> Actualiser
          </button>
        </div>
      </div>
      <section className="panel data-panel">
        <div className="module-toolbar">
          <div className="module-count">{loading ? 'Chargement…' : `${rows.length} résultat${rows.length > 1 ? 's' : ''}`}</div>
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
                  <th style={{ width: path === '/affectations' ? 105 : 45, textAlign: 'center' }}>Actions</th>
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
                        content = <span className={`status-badge ${statusTone(text)}`}>{text}</span>;
                      } else if (column.key === 'priorite' || column.key.endsWith('.priorite')) {
                        content = <span className={`status-badge ${priorityBadge(text)}`}>{text}</span>;
                      }
                      return <td key={column.key}>{content}</td>;
                    })}
                    <td style={{ textAlign: 'center', whiteSpace: 'nowrap' }}>
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
                        {path === '/affectations' && (
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
                            {downloadingPdfId === Number(row.id) ? '...' : 'PDF'}
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
  onClose,
  onCreated,
}: {
  definition: ModuleDefinition;
  token: string | null;
  onClose: () => void;
  onCreated: () => void;
}) {
  const fields = definition.createFields ?? [];
  const [values, setValues] = useState<Record<string, string | boolean>>(() => Object.fromEntries(
    fields.map((field) => [field.name, field.type === 'checkbox' ? false : field.type === 'select' ? field.options?.[0] ?? '' : '']),
  ));
  const [assetOptions, setAssetOptions] = useState<Array<{ id: number; label: string }>>([]);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (fields.some((f) => f.name === 'asset_id')) {
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
  }, [fields, token]);

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
    if (definition.endpoint === '/users' && Boolean(values.username) !== Boolean(values.password)) {
      setError('Pour créer un accès, renseignez à la fois l’identifiant et le mot de passe.');
      return;
    }
    setSaving(true);
    try {
      const body = fields.reduce<Record<string, string | number | boolean>>((result, field) => {
        const value = values[field.name];
        if (field.type === 'checkbox') {
          result[field.name] = Boolean(value);
          return result;
        }
        const text = String(value ?? '').trim();
        if (!text || (field.name === 'role' && !values.username)) return result;
        result[field.name] = field.type === 'number' ? Number(text) : text;
        return result;
      }, {});
      await apiRequest<unknown>(definition.endpoint, {
        method: 'POST',
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
          <div><span className="eyebrow">NOUVEL ENREGISTREMENT</span><h2 id="create-dialog-title">Ajouter à {definition.title.toLowerCase()}</h2></div>
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
            <button className="button button-primary" disabled={saving}>{saving ? <span className="spinner" /> : <Plus size={14} />}{saving ? 'Enregistrement…' : 'Créer'}</button>
          </div>
        </form>
      </section>
    </div>
  );
}

function SearchPage() {
  const { token } = useAuth();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const categories = [
    ['assets', 'Équipements'], ['tickets', 'Tickets'], ['maintenances', 'Maintenances'],
    ['licences', 'Licences'], ['wiki', 'Base de connaissances'],
  ] as const;

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
      <div className="page-heading"><div><span className="eyebrow">GESTION DU PARC</span><h1>Recherche globale</h1><p>Retrouvez un équipement, un ticket ou une procédure.</p></div></div>
      <section className="panel search-panel">
        <form className="global-search" onSubmit={search}>
          <Search size={19} /><input placeholder="Ex. numéro de série, nom, ticket…" value={query} onChange={(event) => setQuery(event.target.value)} aria-label="Recherche globale" />
          <button className="button button-primary" disabled={loading}>{loading ? 'Recherche…' : 'Rechercher'}</button>
        </form>
        {error && <div className="alert alert-error" role="alert"><div><strong>Recherche impossible</strong><span>{error}</span></div></div>}
        {loading && <div className="loading-lines"><i /><i /></div>}
        {results && !loading && <div className="search-results">
          {categories.map(([key, title]) => {
            const rows = extractRows(results[key]);
            return (
              <section className="search-category" key={key}>
                <h2>{title}<span>{rows.length}</span></h2>
                {rows.length ? rows.map((row, index) => <article key={String(row.id ?? index)}><strong>{cellText(row.asset_tag ?? row.numero ?? row.titre ?? row.nom ?? row.nom_machine)}</strong><span>{cellText(row.type ?? row.statut ?? row.description ?? row.categorie)}</span></article>) : <p>Aucun résultat.</p>}
              </section>
            );
          })}
        </div>}
      </section>
    </div>
  );
}

function ReportsPage() {
  const { token } = useAuth();
  const [report, setReport] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    apiRequest<Record<string, unknown>>('/dashboard/reports', { token })
      .then((result) => { if (active) setReport(result); })
      .catch((reason: unknown) => { if (active) setError(reason instanceof Error ? reason.message : 'Impossible de charger les rapports.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [token]);

  const typeData = extractRows(report?.assets_by_type);
  const statutData = extractRows(report?.assets_by_statut);
  const licencesData = extractRows(report?.licences_utilisation);
  const consommablesData = extractRows(report?.consommables_stock);

  const maxType = Math.max(...typeData.map((d) => Number(d.count || 0)), 1);
  const maxStatut = Math.max(...statutData.map((d) => Number(d.count || 0)), 1);

  return (
    <div>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ANALYSE DU PARC</span>
          <h1>Rapports & Indicateurs Clés</h1>
          <p>Indicateurs décisionnels et suivi de conformité du parc informatique.</p>
        </div>
      </div>

      {error && <div className="alert alert-error" role="alert"><div><strong>Erreur de récupération des données</strong><span>{error}</span></div></div>}

      {loading ? (
        <section className="panel"><div className="loading-lines"><i /><i /><i /></div></section>
      ) : (
        <div className="dashboard-columns">
          {/* Équipements par Statut */}
          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>État de Santé du Parc (Statuts)</h2>
                <p>Répartition par condition opérationnelle</p>
              </div>
              <div className="panel-heading-icon green"><Activity size={18} /></div>
            </div>
            <div className="bar-list" style={{ marginTop: 18 }}>
              {statutData.map((item, idx) => {
                const count = Number(item.count || 0);
                const pct = Math.round((count / maxStatut) * 100);
                const st = String(item.statut || 'inconnu');
                return (
                  <div className="bar-item" key={idx}>
                    <div className="bar-item-top">
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                        <span className={`status-badge ${statusTone(st)}`}>{st}</span>
                      </span>
                      <strong>{count} machine{count > 1 ? 's' : ''}</strong>
                    </div>
                    <div className="bar-track">
                      <span style={{ width: `${pct}%`, background: st.includes('service') ? '#10b981' : st.includes('hors') ? '#ef4444' : '#f59e0b' }} />
                    </div>
                  </div>
                );
              })}
              {!statutData.length && <EmptyState text="Aucune donnée de statut." />}
            </div>
          </section>

          {/* Types d'équipements */}
          <section className="panel">
            <div className="panel-heading">
              <div>
                <h2>Parc par Type de Matériel</h2>
                <p>Volume par catégorie de poste</p>
              </div>
              <div className="panel-heading-icon"><Laptop size={18} /></div>
            </div>
            <div className="bar-list" style={{ marginTop: 18 }}>
              {typeData.map((item, idx) => {
                const count = Number(item.count || 0);
                const pct = Math.round((count / maxType) * 100);
                return (
                  <div className="bar-item" key={idx}>
                    <div className="bar-item-top">
                      <span style={{ textTransform: 'capitalize' }}>{String(item.type)}</span>
                      <strong>{count} unité{count > 1 ? 's' : ''}</strong>
                    </div>
                    <div className="bar-track">
                      <span style={{ width: `${pct}%`, background: '#3b82f6' }} />
                    </div>
                  </div>
                );
              })}
              {!typeData.length && <EmptyState text="Aucun équipement recensé." />}
            </div>
          </section>

          {/* Utilisation des Licences */}
          <section className="panel" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2>Taux d'Utilisation des Licences Logicielles</h2>
                <p>Attributions actuelles par rapport aux quotas achetés</p>
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
                    return (
                      <tr key={idx}>
                        <td><strong>{String(lic.nom)}</strong></td>
                        <td>{String(lic.editeur || '—')}</td>
                        <td>{alloc}</td>
                        <td>{quota || 'Illimité'}</td>
                        <td style={{ minWidth: 140 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <div className="bar-track" style={{ flex: 1 }}>
                              <span style={{ width: `${pct}%`, background: pct > 90 ? '#ef4444' : pct > 75 ? '#f59e0b' : '#10b981' }} />
                            </div>
                            <span style={{ fontSize: 10, fontWeight: 700 }}>{pct}%</span>
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
          <section className="panel" style={{ gridColumn: '1 / -1' }}>
            <div className="panel-heading">
              <div>
                <h2>Niveaux de Stocks Consommables</h2>
                <p>Surveillance des consommables par rapport au seuil critique</p>
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
                        <td><strong>{String(item.nom)}</strong></td>
                        <td><span style={{ fontSize: 13, fontWeight: 700 }}>{qte}</span></td>
                        <td>{seuil}</td>
                        <td>
                          <span className={`status-badge ${isLow ? 'status-red' : 'status-green'}`}>
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
        </div>
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
