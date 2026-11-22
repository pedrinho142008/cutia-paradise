(() => {
  'use strict';

  function obterAuth() {
    if (window.CutiaAuth?.db && window.CutiaAuth?.user) {
      return Promise.resolve(window.CutiaAuth);
    }

    return new Promise((resolve, reject) => {
      const limite = setTimeout(
        () => reject(new Error('A autenticação não foi inicializada.')),
        15000
      );

      window.addEventListener('cutia-auth-ready', () => {
        clearTimeout(limite);

        if (window.CutiaAuth?.db && window.CutiaAuth?.user) {
          resolve(window.CutiaAuth);
        } else {
          reject(new Error('Sessão não encontrada.'));
        }
      }, { once: true });
    });
  }

  async function contexto() {
    return await obterAuth();
  }

  async function executar(consulta) {
    const { data, error } = await consulta;
    if (error) throw error;
    return data;
  }

  const DB = {
    async produtos() {
      const { db } = await contexto();

      return executar(
        db.from('products')
          .select('id,name,category,description,price,active,sort_order')
          .eq('active', true)
          .order('sort_order', { ascending: true })
      );
    },

    async comandasTodas() {
      const { db } = await contexto();

      const comandas = await executar(
        db.from('orders')
          .select('*')
          .order('created_at', { ascending: false })
      );

      if (!comandas.length) return [];

      const ids = comandas.map(c => c.id);
      const usuariosIds = [...new Set(comandas.map(c => c.customer_id).filter(Boolean))];

      const perfis = usuariosIds.length
        ? await executar(
            db.from('profiles')
              .select('id,username')
              .in('id', usuariosIds)
          )
        : [];

      const nomesPorId = new Map(
        perfis.map(perfil => [perfil.id, perfil.username])
      );

      const itens = await executar(
        db.from('order_items')
          .select('*')
          .in('order_id', ids)
          .order('created_at', { ascending: true })
      );

      return comandas.map(comanda => ({
        ...comanda,
        garcom: nomesPorId.get(comanda.customer_id) || 'Garçom',
        itens: itens.filter(item => item.order_id === comanda.id)
      }));
    },

    async comandasAbertas() {
      const todas = await this.comandasTodas();
      return todas.filter(c => c.command_status === 'open');
    },

    async criarComanda(dados) {
      const { db, user } = await contexto();

      const identificacao = String(dados.identificacao || '').trim();
      const tipo = dados.tipo === 'Lugar' ? 'Lugar' : 'Mesa';

      if (!identificacao) {
        throw new Error('Informe a mesa ou identificação da comanda.');
      }

      return executar(
        db.from('orders')
          .insert({
            customer_id: user.id,
            customer_name: String(dados.cliente || 'Atendimento').trim(),
            table_number: identificacao,
            identification: identificacao,
            command_type: tipo,
            command_status: 'open',
            status: 'pending_waiter',
            notes: dados.observacoes || null
          })
          .select()
          .single()
      );
    },

    async adicionarItem(orderId, produto, quantidade = 1, observacoes = '') {
      const { db } = await contexto();

      if (!produto?.id) throw new Error('Produto inválido.');
      if (!Number.isInteger(Number(quantidade)) || Number(quantidade) < 1) {
        throw new Error('Quantidade inválida.');
      }

      return executar(
        db.from('order_items')
          .insert({
            order_id: orderId,
            product_id: produto.id,
            product_name: produto.name,
            category: produto.category,
            unit_price: Number(produto.price),
            quantity: Number(quantidade),
            notes: observacoes || null,
            status: 'pending',
            kitchen_status: 'waiting',
            kitchen_confirmation: 'pending',
            sent_to_kitchen: false
          })
          .select()
          .single()
      );
    },

    async editarItem(itemId, quantidade, observacoes = '') {
      const { db } = await contexto();

      return executar(
        db.from('order_items')
          .update({
            quantity: Number(quantidade),
            notes: observacoes || null
          })
          .eq('id', itemId)
          .eq('kitchen_status', 'waiting')
          .eq('sent_to_kitchen', false)
          .eq('kitchen_confirmation', 'pending')
          .select()
          .single()
      );
    },

    async removerItem(itemId) {
      const { db } = await contexto();

      const removidos = await executar(
        db.from('order_items')
          .delete()
          .eq('id', itemId)
          .eq('kitchen_status', 'waiting')
          .eq('sent_to_kitchen', false)
          .in('kitchen_confirmation', ['pending', 'rejected'])
          .select('id')
      );

      if (!Array.isArray(removidos) || removidos.length === 0) {
        throw new Error(
          'Nenhum registro foi removido. Verifique se o produto ainda existe e se a política de segurança permite sua exclusão.'
        );
      }

      return removidos[0];
    },

    async enviarItensComanda(orderId) {
      const { db } = await contexto();

      const normalizar = valor => String(valor || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/&/g, ' e ')
        .replace(/\s+/g, ' ')
        .trim();

      const permitidas = new Set([
        'doses',
        'drinks',
        'sucos naturais',
        'petiscos',
        'refeicoes',
        'caldos',
        'entradas e porcoes',
        'entrada e porcoes'
      ]);

      const rascunhos = await executar(
        db.from('order_items')
          .select('id,category')
          .eq('order_id', orderId)
          .eq('sent_to_kitchen', false)
          .eq('kitchen_status', 'waiting')
      );

      const idsPermitidos = (rascunhos || [])
        .filter(item => permitidas.has(normalizar(item.category)))
        .map(item => item.id);

      if (!idsPermitidos.length) {
        return [];
      }

      return executar(
        db.from('order_items')
          .update({ sent_to_kitchen: true })
          .in('id', idsPermitidos)
          .eq('order_id', orderId)
          .eq('sent_to_kitchen', false)
          .eq('kitchen_status', 'waiting')
          .select()
      );
    },

    async avancarItem(itemId, proximoStatus) {
      const { db } = await contexto();

      const etapas = {
        preparing: 'preparing',
        ready: 'ready',
        delivered: 'delivered'
      };

      if (!etapas[proximoStatus]) {
        throw new Error('Etapa de produção inválida.');
      }

      return executar(
        db.from('order_items')
          .update({
            kitchen_status: proximoStatus,
            status: proximoStatus
          })
          .eq('id', itemId)
          .eq('sent_to_kitchen', true)
          .select()
          .single()
      );
    },

    async fecharComanda(orderId, total, pagamento) {
      const { db } = await contexto();

      return executar(
        db.from('orders')
          .update({
            command_status: 'closed',
            status: 'completed',
            closed_at: new Date().toISOString(),
            closed_total: Number(total),
            payment_method: pagamento
          })
          .eq('id', orderId)
          .eq('command_status', 'open')
          .select()
          .single()
      );
    },

    async reabrirComanda(orderId) {
      const { db } = await contexto();

      // Preserva closed_at, closed_total e payment_method.
      return executar(
        db.from('orders')
          .update({
            command_status: 'open',
            status: 'pending_waiter'
          })
          .eq('id', orderId)
          .eq('command_status', 'closed')
          .select()
          .single()
      );
    },

    async arquivarComanda(orderId) {
      const { db } = await contexto();

      return executar(
        db.from('orders')
          .update({ archived_at: new Date().toISOString() })
          .eq('id', orderId)
          .eq('command_status', 'closed')
          .is('archived_at', null)
          .select()
          .single()
      );
    },

    async restaurarComanda(orderId) {
      const { db } = await contexto();

      return executar(
        db.from('orders')
          .update({ archived_at: null })
          .eq('id', orderId)
          .not('archived_at', 'is', null)
          .select()
          .single()
      );
    },

    async sincronizar(callback) {
      const { db } = await contexto();

      const canal = db.channel('cutia-pedidos')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'orders'
        }, payload => {
          console.info('[Cutia Realtime] Alteração em orders:', payload.eventType);
          callback(payload);
        })
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'order_items'
        }, payload => {
          console.info('[Cutia Realtime] Alteração em order_items:', payload.eventType);
          callback(payload);
        })
        .subscribe((status, error) => {
          console.info('[Cutia Realtime] Conexão:', status);

          if (status === 'SUBSCRIBED') {
            console.info('[Cutia Realtime] Conectado. Sincronizando dados...');
            callback({ tipo: 'conexao_estabelecida' });
          }

          if (
            status === 'CHANNEL_ERROR' ||
            status === 'TIMED_OUT' ||
            status === 'CLOSED'
          ) {
            console.error('[Cutia Realtime] Problema na conexão:', status, error || '');
          }
        });

      return canal;
    },

    async cancelarSincronizacao(canal) {
      if (!canal) return;
      const { db } = await contexto();
      await db.removeChannel(canal);
    }
  };

  window.CutiaDB = DB;
})();
