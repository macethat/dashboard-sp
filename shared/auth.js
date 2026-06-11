const Auth = {
  _baseUrl: '',
  _anonKey: '',
  _session: null,
  _profile: null,
  _listeners: [],

  init() {
    const cfg = APP_CONFIG.supabase;
    if (!cfg.enabled || !cfg.url || !cfg.anonKey) return;
    this._baseUrl = cfg.url.replace(/\/+$/, '') + '/auth/v1';
    this._anonKey = cfg.anonKey;
    this._session = this._loadSession();
    if (this._session) {
      this._loadProfile().then(() => this._notify());
    }
  },

  _headers(useToken) {
    const h = {
      'apikey': this._anonKey,
      'Content-Type': 'application/json'
    };
    if (useToken && this._session) h['Authorization'] = 'Bearer ' + this._session.access_token;
    return h;
  },

  _saveSession(session) {
    this._session = session;
    if (session) {
      localStorage.setItem('sp_auth_session', JSON.stringify(session));
    } else {
      localStorage.removeItem('sp_auth_session');
    }
  },

  _loadSession() {
    try {
      const d = localStorage.getItem('sp_auth_session');
      return d ? JSON.parse(d) : null;
    } catch { return null; }
  },

  async _loadProfile() {
    if (!this._session) return;
    try {
      const res = await fetch(this._baseUrl.replace('/auth/v1', '/rest/v1/profiles?id=eq.' + this._session.user.id + '&select=*'), {
        headers: this._headers(true)
      });
      if (res.ok) {
        const data = await res.json();
        this._profile = data[0] || null;
      }
    } catch (e) {
      console.warn('Profile load failed:', e);
    }
  },

  async login(email, password) {
    const res = await fetch(this._baseUrl + '/token?grant_type=password', {
      method: 'POST',
      headers: this._headers(false),
      body: JSON.stringify({ email, password })
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error_description || err.error || 'Error al iniciar sesión');
    }
    const data = await res.json();
    this._saveSession({
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      user: data.user,
      expires_at: Date.now() + (data.expires_in || 3600) * 1000
    });
    await this._loadProfile();
    this._notify();
    return this._session.user;
  },

  async logout() {
    if (this._session) {
      try {
        await fetch(this._baseUrl + '/logout', {
          method: 'POST',
          headers: this._headers(true)
        });
      } catch {}
    }
    this._saveSession(null);
    this._profile = null;
    this._notify();
  },

  getUser() {
    return this._session?.user || null;
  },

  getProfile() {
    return this._profile;
  },

  _getRole() {
    return this._profile?.role || this._session?.user?.user_metadata?.role || '';
  },

  isLoggedIn() {
    return !!this._session;
  },

  isAdmin() {
    return this._getRole() === 'admin';
  },

  isSupervisor() {
    return this._getRole() === 'supervisor';
  },

  isSpecialist() {
    return this._getRole() === 'editor';
  },

  canEdit() {
    const r = this._getRole();
    return r === 'admin' || r === 'editor';
  },

  getDepartment() {
    return this._profile?.department || '';
  },

  getDisplayName() {
    return this._profile?.display_name || this._session?.user?.email || 'Usuario';
  },

  getDashboardTitle() {
    const dept = this.getDepartment();
    const name = this.getDisplayName();
    if (this.isAdmin()) return 'Dashboard - Suplementos Panamá - Admin';
    if (dept) return 'Dashboard - ' + dept + ' - ' + name;
    return 'Dashboard - Suplementos Panamá';
  },

  getDashboardSubtitle() {
    const dept = this.getDepartment();
    if (this.isAdmin()) return 'Acceso completo';
    if (dept) return 'Departamento de ' + dept;
    return 'Suplementos Panamá';
  },

  onChange(fn) {
    this._listeners.push(fn);
  },

  _notify() {
    this._listeners.forEach(fn => fn(this._session ? this._profile : null));
  },

  async changePassword(newPassword) {
    if (!this._session) throw new Error('No hay sesión activa');
    const res = await fetch(this._baseUrl + '/user', {
      method: 'PUT',
      headers: this._headers(true),
      body: JSON.stringify({ password: newPassword })
    });
    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.msg || err.error_description || 'Error al cambiar contraseña');
    }
    return true;
  },

  async refreshSession() {
    if (!this._session?.refresh_token) return false;
    try {
      const res = await fetch(this._baseUrl + '/token?grant_type=refresh_token', {
        method: 'POST',
        headers: this._headers(false),
        body: JSON.stringify({ refresh_token: this._session.refresh_token })
      });
      if (!res.ok) { this.logout(); return false; }
      const data = await res.json();
      this._saveSession({
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        user: data.user,
        expires_at: Date.now() + (data.expires_in || 3600) * 1000
      });
      return true;
    } catch { this.logout(); return false; }
  }
};
