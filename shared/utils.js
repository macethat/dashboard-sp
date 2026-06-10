                              /**
 * ==========================================
 * UTILIDADES COMPARTIDAS - Suplementos Panamá
 * ==========================================
 * Funciones reutilizables por Dashboard y Admin.
 * ==========================================
 */

const Utils = {

    // === Formatear fecha larga ===
    formatDate(dateStr) {
        if (!dateStr) return '-';
        const d = new Date(dateStr + 'T00:00:00');
        return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' });
    },

    // === Formatear fecha corta ===
    formatDateShort(dateStr) {
        if (!dateStr) return '-';
        const d = new Date(dateStr + 'T00:00:00');
        return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
    },

    // === Formatear fecha y hora ===
    formatDateTime(dateStr) {
        if (!dateStr) return '-';
        const d = new Date(dateStr);
        return d.toLocaleString('es-ES');
    },

    // === Traducir estado a texto ===
    getStatusLabel(status) {
        const labels = {
            'pendiente': 'Pendiente',
            'en-progreso': 'En Progreso',
            'revision': 'En Revisión',
            'completado': 'Completado',
            'cancelado': 'Cancelado'
        };
        return labels[status] || status;
    },

    // === Obtener nombre de una etiqueta por su ID ===
    getTagName(tagId) {
        const tag = DB.tags.find(t => t.id === tagId);
        return tag ? tag.name : '';
    },

    // === Obtener nombre de un proyecto por su ID ===
    getProjectName(projectId) {
        const proj = DB.projects.find(p => p.id === projectId);
        return proj ? proj.name : '';
    },

    // === Obtener prioridad con icono ===
    getPriorityLabel(priority) {
        const labels = { 'alta': '🔴 Alta', 'media': '🟡 Media', 'baja': '🟢 Baja' };
        return labels[priority] || priority;
    },

    // ==========================================
    // === TOAST (Notificación visual) ===
    // ==========================================
    showToast(title, message, type) {
        const toast = document.getElementById('notificationToast') || document.getElementById('toast');
        if (!toast) return;

        const titleEl = document.getElementById('toastTitle');
        const msgEl = document.getElementById('toastMessage') || document.getElementById('toastMsg');

        if (titleEl) titleEl.textContent = title;
        if (msgEl) msgEl.textContent = message;

        toast.classList.add('show');
        setTimeout(() => {
            toast.classList.remove('show');
        }, 4000);
    },

    // ==========================================
    // === NOTIFICACIONES DEL NAVEGADOR ===
    // ==========================================
    sendNotification(title, body) {
        if ('Notification' in window && Notification.permission === 'granted') {
            try {
                new Notification(title, {
                    body: body,
                    icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">📋</text></svg>'
                });
            } catch (e) {
                console.warn('Notificación falló:', e);
            }
        }
    },

    requestNotificationPermission() {
        if ('Notification' in window) {
            Notification.requestPermission().then(permission => {
                if (permission === 'granted') {
                    Utils.showToast('Notificaciones activadas', 'Recibirás alertas de actualizaciones');
                } else {
                    Utils.showToast('Permiso denegado', 'Las notificaciones no están permitidas', 'warning');
                }
            });
        } else {
            Utils.showToast('No soportado', 'Tu navegador no soporta notificaciones', 'warning');
        }
    },

    // ==========================================
    // === TEMA VISUAL ===
    // ==========================================
    changeTheme(theme) {
        const html = document.documentElement;
        const select = document.getElementById('themeSelect');
        if (select) select.value = theme;

        if (theme === 'auto') {
            const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            html.setAttribute('data-theme', isDark ? 'dark' : 'light');
        } else {
            html.setAttribute('data-theme', theme);
        }
        localStorage.setItem('sp_theme', theme);
    },

    initTheme() {
        const saved = localStorage.getItem('sp_theme') || 'light';
        Utils.changeTheme(saved);

        // Escuchar cambios del sistema en modo auto
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
            if (localStorage.getItem('sp_theme') === 'auto') {
                Utils.changeTheme('auto');
            }
        });
    },

    // ==========================================
    // === EXPORTAR / IMPORTAR DATOS ===
    // ==========================================
    exportDataToFile() {
        const data = DB.exportData();
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'suplementos_panama_backup_' + new Date().toISOString().split('T')[0] + '.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        Utils.showToast('Datos exportados', 'El archivo de respaldo se ha descargado');
    },

    importDataFromFile(file, callback) {
        if (!file) return;
        const reader = new FileReader();
        reader.onload = function(e) {
            try {
                const data = JSON.parse(e.target.result);
                DB.importData(data);
                if (callback) callback(data);
                Utils.showToast('Datos importados', 'Los datos se han restaurado exitosamente');
            } catch (err) {
                Utils.showToast('Error', 'El archivo no es válido: ' + err.message, 'error');
            }
        };
        reader.readAsText(file);
    },

    // ==========================================
    // === VALIDACIONES ===
    // ==========================================
    isValidEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    },

    isValidDate(dateStr) {
        if (!dateStr) return false;
        const d = new Date(dateStr);
        return d instanceof Date && !isNaN(d);
    },

    // ==========================================
    // === UTILIDADES VARIAS ===
    // ==========================================
    capitalizeFirst(str) {
        if (!str) return '';
        return str.charAt(0).toUpperCase() + str.slice(1);
    },

    truncate(str, length) {
        if (!str) return '';
        return str.length > length ? str.substring(0, length) + '...' : str;
    },

    escapeHtml(str) {
        if (!str) return '';
        const map = { '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;' };
        return str.replace(/[&<>"']/g, m => map[m]);
    },

    // === Obtener color aleatorio para etiquetas nuevas ===
    getRandomColor() {
        const colors = ['#e74c3c','#3498db','#27ae60','#f39c12','#9b59b6','#1abc9c','#e67e22','#34495e','#e91e63','#00bcd4'];
        return colors[Math.floor(Math.random() * colors.length)];
    },

    // === Imprimir página ===
    printPage() {
        window.print();
    }
};

// === Inicializar tema al cargar ===
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => Utils.initTheme());
} else {
    Utils.initTheme();
}
