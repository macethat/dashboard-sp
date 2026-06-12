const DB = {
  tasks: [],
  projects: [],
  tags: [],
  connections: [],
  reports: [],
  _currentUser: null,
  _currentProfile: null,

  init() {
    this.tasks = [];
    this.projects = [];
    this.tags = [];
    this.connections = [];
    this.reports = [];
    this._supabaseReady = false;
    if (typeof APP_CONFIG !== 'undefined' && APP_CONFIG.supabase.enabled) {
      this._initSupabase();
    }
  },

  setUser(user, profile) {
    this._currentUser = user;
    this._currentProfile = profile;
  },

  save() {
    if (this._supabaseReady) this._syncToSupabase();
  },

  genId() {
    return 'id_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  },

  addTask(task) {
    task.id = task.id || this.genId();
    task.created = task.created || new Date().toISOString().split('T')[0];
    task.progress = typeof task.progress === 'number' ? task.progress : 0;
    task.incidents = task.incidents || [];
    if (this._currentUser) task.created_by = this._currentUser.id;
    if (this._currentProfile) task.department = this._currentProfile.department || '';
    this.tasks.push(task);
    this.save();
    return task;
  },

  updateTask(id, data) {
    const index = this.tasks.findIndex(t => t.id === id);
    if (index !== -1) {
      const oldStatus = this.tasks[index].status;
      this.tasks[index] = { ...this.tasks[index], ...data };
      if (oldStatus !== data.status && data.status) {
        if (!this.tasks[index].incidents) this.tasks[index].incidents = [];
        this.tasks[index].incidents.push({
          date: new Date().toISOString().split('T')[0],
          type: 'estado',
          desc: 'Estado cambiado a "' + this._getStatusLabel(data.status) + '"'
        });
      }
      this.save();
    }
  },

  deleteTask(id) {
    this.tasks = this.tasks.filter(t => t.id !== id);
    this.connections = this.connections.filter(c => c.source !== id && c.target !== id);
    this.save();
  },

  getTask(id) {
    return this.tasks.find(t => t.id === id);
  },

  addProject(project) {
    project.id = project.id || this.genId();
    if (this._currentUser) project.created_by = this._currentUser.id;
    if (this._currentProfile) project.department = this._currentProfile.department || '';
    if (project.is_team) {
      project.members = project.members || [];
    }
    this.projects.push(project);
    this.save();
    return project;
  },

  updateProject(id, data) {
    const index = this.projects.findIndex(p => p.id === id);
    if (index !== -1) {
      this.projects[index] = { ...this.projects[index], ...data };
      this.save();
    }
  },

  deleteProject(id) {
    this.projects = this.projects.filter(p => p.id !== id);
    this.tasks.forEach(t => { if (t.projectId === id) t.projectId = ''; });
    this.save();
  },

  addTag(tag) {
    tag.id = tag.id || this.genId();
    this.tags.push(tag);
    this.save();
    return tag;
  },

  updateTag(id, data) {
    const index = this.tags.findIndex(t => t.id === id);
    if (index !== -1) {
      this.tags[index] = { ...this.tags[index], ...data };
      this.save();
    }
  },

  deleteTag(id) {
    this.tags = this.tags.filter(t => t.id !== id);
    this.tasks.forEach(t => {
      if (t.tags) t.tags = t.tags.filter(tid => tid !== id);
    });
    this.save();
  },

  addConnection(conn) {
    conn.id = conn.id || this.genId();
    if (this._currentUser) conn.created_by = this._currentUser.id;
    if (this._currentProfile) conn.department = this._currentProfile.department || '';
    this.connections.push(conn);
    this.save();
    return conn;
  },

  deleteConnection(id) {
    this.connections = this.connections.filter(c => c.id !== id);
    this.save();
  },

  addReport(report) {
    report.id = report.id || this.genId();
    report.date = report.date || new Date().toISOString();
    this.reports.push(report);
    this.save();
    return report;
  },

  deleteReport(id) {
    this.reports = this.reports.filter(r => r.id !== id);
    this.save();
  },

  exportData() {
    return {
      tasks: this.tasks,
      projects: this.projects,
      tags: this.tags,
      connections: this.connections,
      reports: this.reports,
      exportDate: new Date().toISOString()
    };
  },

  importData(data) {
    if (data.tasks) this.tasks = data.tasks;
    if (data.projects) this.projects = data.projects;
    if (data.tags) this.tags = data.tags;
    if (data.connections) this.connections = data.connections;
    if (data.reports) this.reports = data.reports;
    this.save();
  },

  async clearAll() {
    this.tasks = [];
    this.projects = [];
    this.tags = [];
    this.connections = [];
    this.reports = [];
    if (this._supabaseReady) {
      for (const table of ['tasks','projects','tags','connections','reports']) {
        try {
          await fetch(this._sbUrl + '/' + table + '?id=not.eq.x', {
            method: 'DELETE',
            headers: { ...this._sbHeaders(!!this._currentUser), 'Prefer': 'return=minimal' }
          });
        } catch(e) {}
      }
    }
  },

  getStats() {
    const total = this.tasks.length;
    const completed = this.tasks.filter(t => t.status === 'completado').length;
    const inProgress = this.tasks.filter(t => t.status === 'en-progreso').length;
    const pending = this.tasks.filter(t => t.status === 'pendiente').length;
    const review = this.tasks.filter(t => t.status === 'revision').length;
    const cancelled = this.tasks.filter(t => t.status === 'cancelado').length;
    const totalIncidents = this.tasks.reduce((sum, t) => sum + (t.incidents ? t.incidents.length : 0), 0);
    return {
      totalTasks: total,
      completed,
      inProgress,
      pending,
      review,
      cancelled,
      totalProjects: this.projects.length,
      totalTags: this.tags.length,
      totalConnections: this.connections.length,
      totalReports: this.reports.length,
      totalIncidents,
      overallProgress: total > 0 ? Math.round((completed / total) * 100) : 0
    };
  },

  _getStatusLabel(status) {
    const labels = {
      'pendiente': 'Pendiente',
      'en-progreso': 'En Progreso',
      'revision': 'En Revisión',
      'completado': 'Completado',
      'cancelado': 'Cancelado'
    };
    return labels[status] || status;
  },

  _initSupabase() {
    try {
      const cfg = APP_CONFIG.supabase;
      if (!cfg.url || !cfg.anonKey) return;
      this._sbUrl = cfg.url.replace(/\/+$/, '') + '/rest/v1';
      this._sbKey = cfg.anonKey;
      this._supabaseReady = true;
      this._syncFromSupabase();
    } catch (e) {
      console.warn('Supabase init failed:', e);
    }
  },

  _sbHeaders(useUserToken) {
    const token = (useUserToken && typeof Auth !== 'undefined' && Auth._session)
      ? Auth._session.access_token
      : this._sbKey;
    return {
      'apikey': this._sbKey,
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal'
    };
  },

  _sbMap(row, table) {
    const m = { ...row, updated_at: new Date().toISOString() };
    if (table === 'tasks') {
      if (m.dueDate && !m.due_date) { m.due_date = m.dueDate; delete m.dueDate; }
      if (m.projectId && !m.project_id) { m.project_id = m.projectId; delete m.projectId; }
      if (this._currentUser && !m.created_by) m.created_by = this._currentUser.id;
      if (this._currentProfile && !m.department) m.department = this._currentProfile.department || '';
    }
    if (table === 'projects') {
      if (this._currentUser && !m.created_by) m.created_by = this._currentUser.id;
      if (this._currentProfile && !m.department) m.department = this._currentProfile.department || '';
      if (m.members && typeof m.members === 'string') {
        try { m.members = JSON.parse(m.members); } catch(e) { m.members = []; }
      }
      if (!m.members) m.members = [];
      if (m.is_team === undefined || m.is_team === null) m.is_team = false;
    }
    if (table === 'connections') {
      if (this._currentUser && !m.created_by) m.created_by = this._currentUser.id;
      if (this._currentProfile && !m.department) m.department = this._currentProfile.department || '';
    }
    return m;
  },

  async _syncToSupabase() {
    try {
      const tables = ['tasks', 'projects', 'tags', 'connections', 'reports'];
      for (const table of tables) {
        const rows = this[table].map(r => this._sbMap(r, table));
        if (!rows.length) continue;
        const res = await fetch(this._sbUrl + '/' + table, {
          method: 'POST',
          headers: { ...this._sbHeaders(!!this._currentUser), 'Prefer': 'resolution=merge-duplicates' },
          body: JSON.stringify(rows)
        });
        if (!res.ok) {
          const text = await res.text();
          console.warn('Supabase sync error (' + table + '):', res.status, text);
        }
      }
    } catch (e) {
      console.warn('Supabase sync failed:', e);
    }
  },

  _sbUnmap(row, table) {
    const m = { ...row };
    delete m.updated_at;
    if (table === 'tasks') {
      if (m.due_date && !m.dueDate) { m.dueDate = m.due_date; delete m.due_date; }
      if (m.project_id && !m.projectId) { m.projectId = m.project_id; delete m.project_id; }
    }
    if (table === 'projects') {
      if (m.members && typeof m.members === 'string') {
        try { m.members = JSON.parse(m.members); } catch(e) { m.members = []; }
      }
    }
    return m;
  },

  async _syncFromSupabase() {
    try {
      const tables = ['tasks', 'projects', 'tags', 'connections', 'reports'];
      for (const table of tables) {
        let url = this._sbUrl + '/' + table + '?select=*';
        const headers = this._sbHeaders(!!this._currentUser);
        const res = await fetch(url, { headers });
        if (!res.ok) continue;
        const data = await res.json();
        if (data && data.length) {
          this[table] = data.map(r => this._sbUnmap(r, table));
        }
      }
    } catch (e) {
      console.warn('Supabase sync from failed:', e);
    }
  },

  async loadFromSupabase() {
    if (this._supabaseReady) await this._syncFromSupabase();
  }
};

DB.init();
