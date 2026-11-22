(() => {
  'use strict';

  const config = window.CUTIA_CONFIG;
  const clientLib = window.supabase;

  if (!config?.url || !config?.key || !clientLib?.createClient) {
    document.documentElement.style.visibility = 'visible';
    alert('Não foi possível carregar a conexão com o Supabase.');
    location.replace('login.html');
    return;
  }

  const db = clientLib.createClient(config.url, config.key);
  window.supabaseClient = db;

  const file = location.pathname.split('/').pop();
  const requiredRole = file === 'cozinha.html' ? 'kitchen' : 'waiter';
  const allowedRoles = [requiredRole, 'admin'];

  document.documentElement.style.visibility = 'hidden';

  async function protect() {
    try {
      const { data: sessionData, error: sessionError } =
        await db.auth.getSession();

      if (sessionError) throw sessionError;

      const user = sessionData.session?.user;

      if (!user) {
        location.replace('login.html');
        return;
      }

      const { data: profile, error: profileError } = await db
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

      if (profileError) throw profileError;

      if (!profile || !allowedRoles.includes(profile.role)) {
        await db.auth.signOut();
        location.replace('login.html');
        return;
      }

      window.CutiaAuth = {
        db,
        user,
        role: profile.role,
        async logout() {
          await db.auth.signOut();
          location.replace('login.html');
        }
      };

      document.documentElement.style.visibility = 'visible';
      window.dispatchEvent(new Event('cutia-auth-ready'));

    } catch (error) {
      console.error('Falha na autenticação Cutia:', error);
      await db.auth.signOut().catch(() => {});
      location.replace('login.html');
    }
  }

  protect();
})();
