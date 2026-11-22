# Cutia Paradise — Cardápio digital e pedidos

Sistema web responsivo com três áreas sincronizadas:

- **Cliente:** navega pelo cardápio original clicável ou pela lista de produtos, monta o pedido, informa nome e mesa e acompanha o andamento.
- **Garçom:** recebe os novos pedidos, confirma/corrige a mesa e encaminha para a cozinha.
- **Cozinha:** vê a fila, inicia o preparo e marca cada item como pronto para sair.
- **Garçom:** recebe as atualizações e marca os itens como entregues.
- **Cliente:** acompanha os estados em tempo real e recebe aviso sonoro com a página aberta e os avisos ativados.

O sistema usa Supabase para autenticação, banco de dados, políticas de acesso e atualizações em tempo real.

## 1. Criar o banco Supabase

1. Crie um projeto em https://supabase.com/.
2. Abra **SQL Editor → New query**.
3. Copie todo o conteúdo de `supabase.sql`, cole e execute.
4. Em **Authentication → Sign In / Providers**, habilite **Anonymous Sign-Ins** para que o cliente consiga enviar pedido sem criar conta.
5. Em **Project Settings → API**, copie a **Project URL** e a chave pública **publishable** (ou a chave pública `anon` legada).

O SQL cria o catálogo, pedidos, itens, perfis, permissões RLS e habilita Realtime nas tabelas de pedidos.

## 2. Configurar o site

Abra `config.js` e preencha:

```js
window.CUTIA_CONFIG = {
  url: 'https://SEU-PROJETO.supabase.co',
  key: 'SUA_CHAVE_PUBLICA_PUBLISHABLE_OU_ANON'
};
```

Não use a chave `service_role`. A chave pública pode ficar no front-end porque as permissões são controladas pelas políticas RLS do banco.

Também é possível abrir o site sem preencher `config.js`: aparecerá uma tela para inserir URL e chave no navegador. Para um site público, prefira preencher `config.js` uma única vez antes de publicar.

## 3. Criar os acessos da equipe

1. No Supabase, abra **Authentication → Users → Add user**.
2. Crie um usuário com e-mail e senha para cada pessoa da equipe.
3. Depois de criar a conta, abra **SQL Editor** e execute o comando correspondente, trocando o e-mail:

Garçom:

```sql
update public.profiles set role = 'waiter'
where id = (select id from auth.users where email = 'garcom@seudominio.com');
```

Cozinha:

```sql
update public.profiles set role = 'kitchen'
where id = (select id from auth.users where email = 'cozinha@seudominio.com');
```

Gerente com acesso aos dois painéis:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'gerente@seudominio.com');
```

## 4. Publicar

É um site estático: publique a pasta inteira em Vercel, Netlify ou hospedagem que sirva arquivos estáticos. Não remova `assets/cardapio-original.jpg` nem `config.js`.

Rotas:

- Cliente: `/`
- Garçom: `/?painel=garcom`
- Cozinha: `/?painel=cozinha`

Os painéis da equipe exigem login e validam a função cadastrada em `profiles`.

## 5. Como o pedido percorre o sistema

1. O cliente adiciona produtos, informa nome e mesa e envia.
2. O pedido aparece para o garçom como **Aguardando garçom**.
3. O garçom confirma a mesa e toca em **Confirmar mesa e enviar à cozinha**.
4. A cozinha recebe o pedido, inicia o preparo e marca os itens individualmente como **Pronto / enviar**.
5. O cliente e o garçom veem as alterações em tempo real.
6. O garçom marca cada item como entregue; quando todos forem entregues, o pedido fica como **Entregue**.

## Aviso sonoro

O cliente precisa tocar em **Ativar som** pelo menos uma vez no aparelho para liberar o áudio do navegador. Com a tela do pedido aberta, alterações de status geram um aviso sonoro. Se a página for fechada ou o navegador suspender totalmente o site, o som não é garantido. Para alertas mesmo com o navegador fechado ou o celular bloqueado, é necessário acrescentar Web Push/PWA com service worker e um serviço de envio de notificações.

## Observações sobre o cardápio enviado

- Os nomes e valores foram transcritos da imagem anexada.
- A linha extra de refrigerante que aparece com preço, mas sem nome legível na imagem, não foi cadastrada para evitar inventar um produto.
- “Caranguejo Prata lata” foi mantido como aparece na imagem, embora o texto esteja parcialmente cortado.
- O cardápio original continua disponível como imagem e os itens foram organizados em uma lista acessível para facilitar o toque no celular.
