-- CUTIA PARADISE | Banco de dados e permissões
-- Execute este arquivo inteiro no SQL Editor do Supabase.
-- A chave service_role NUNCA deve ser usada no navegador.

create extension if not exists pgcrypto;

-- Perfis: novos usuários começam como customer.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer','waiter','kitchen','admin')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, 'customer')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_staff(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = any(allowed_roles)
  );
$$;

create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  description text,
  price numeric(10,2) not null check (price >= 0),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id),
  customer_name text not null,
  table_number text not null,
  notes text,
  status text not null default 'pending_waiter'
    check (status in ('pending_waiter','sent_to_kitchen','preparing','ready','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_to_kitchen_at timestamptz,
  started_at timestamptz
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id text references public.products(id),
  product_name text not null,
  category text not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 50),
  notes text,
  status text not null default 'pending'
    check (status in ('pending','preparing','ready','delivered')),
  created_at timestamptz not null default now()
);

create index if not exists orders_customer_id_idx on public.orders(customer_id);
create index if not exists orders_status_created_idx on public.orders(status, created_at);
create index if not exists order_items_order_id_idx on public.order_items(order_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
before update on public.orders
for each row execute procedure public.set_updated_at();

-- Catálogo transcrito do cardápio enviado.
insert into public.products (id,name,category,description,price,sort_order) values
('heineken-long-neck','Heineken long neck','Bebidas',null,11,1),
('budweiser-long-neck','Budweiser long neck','Bebidas',null,10,2),
('itaipava-lata','Itaipava lata','Bebidas',null,5,3),
('devassa-lata','Devassa lata','Bebidas',null,5,4),
('pitu-limao','Pitú limão','Bebidas',null,10,5),
('caranguejo-prata','Caranguejo Prata lata','Bebidas',null,10,6),
('cerveja-malzbier','Cerveja Malzbier','Bebidas',null,6,7),
('coca-cola-lata','Coca-Cola lata','Refrigerantes',null,6,8),
('coca-zero-lata','Coca Zero lata','Refrigerantes',null,6,9),
('guarana-lata','Guaraná lata','Refrigerantes',null,6,10),
('coca-cola-1l','Coca-Cola 1L','Refrigerantes',null,12,11),
('pepsi-1l','Pepsi 1L','Refrigerantes',null,10,12),
('guarana-1l','Guaraná 1L','Refrigerantes',null,10,13),
('cachaca','Cachaça','Doses',null,3,14),
('conhaque','Conhaque','Doses',null,5,15),
('caipirinha-tradicional','Caipirinha tradicional','Drinks',null,10,16),
('caipirinha-cremosa','Caipirinha cremosa','Drinks',null,12,17),
('caipifruta','Caipifruta','Drinks',null,12,18),
('suco-maracuja','Maracujá','Sucos Naturais',null,8,19),
('suco-goiaba','Goiaba','Sucos Naturais',null,6,20),
('suco-acerola','Acerola','Sucos Naturais',null,6,21),
('suco-limao','Limão','Sucos Naturais',null,6,22),
('suco-laranja','Laranja','Sucos Naturais',null,8,23),
('camarao-alho-oleo','Camarão alho e óleo','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',80,24),
('camarao-crocante','Camarão crocante','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',90,25),
('file-fritas','Filé com fritas','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,26),
('frango-crocante','Frango crocante','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,27),
('frango-passarinha','Frango à passarinha','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,28),
('calabresa-acebolada','Calabresa acebolada','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',45,29),
('peixe-frito','Peixe frito','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',80,30),
('galinha-caipira','Galinha caipira completa','Refeições','Feijão verde, arroz, macarrão, pirão, farofa e vinagrete.',180,31),
('executivo-4','Prato executivo para 4 pessoas','Refeições',null,100,32),
('executivo-2','Prato executivo para 2 pessoas','Refeições',null,50,33),
('prato-feito','Prato feito','Refeições',null,20,34),
('caldo-camarao','Caldo de camarão','Caldos',null,15,35),
('caldo-sertanejo','Caldo sertanejo','Caldos',null,15,36),
('caldo-mocoto','Caldo de mocotó','Caldos',null,15,37),
('caldo-polvo','Caldo de polvo','Caldos',null,15,38),
('batatinha-frita','Batatinha frita','Entrada & Porções',null,20,39),
('macaxeira-frita','Macaxeira frita','Entrada & Porções',null,20,40),
('mini-pastel','Mini pastel (porção com 8 unidades)','Entrada & Porções',null,20,41),
('pastel-tradicional','Pastel tradicional','Entrada & Porções',null,8,42),
('macarrao','Macarrão','Entrada & Porções',null,10,43),
('arroz','Arroz','Entrada & Porções',null,10,44),
('salada','Salada','Entrada & Porções',null,5,45),
('bolinho-macaxeira','Bolinho de macaxeira','Entrada & Porções',null,6,46),
('tapioca-recheada','Tapioca recheada','Entrada & Porções',null,12,47)
on conflict (id) do update set
  name=excluded.name, category=excluded.category, description=excluded.description,
  price=excluded.price, sort_order=excluded.sort_order;

-- Cria o pedido e seus itens em uma única transação, usando os preços do banco.
create or replace function public.place_order(
  p_table_number text,
  p_customer_name text,
  p_notes text,
  p_items jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_order_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_quantity integer;
begin
  if auth.uid() is null then
    raise exception 'Sessão do cliente não encontrada.';
  end if;
  if coalesce(trim(p_table_number),'') = '' then
    raise exception 'Informe o número da mesa.';
  end if;
  if coalesce(trim(p_customer_name),'') = '' then
    raise exception 'Informe seu nome.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 then
    raise exception 'O pedido precisa ter pelo menos um item.';
  end if;

  insert into public.orders(customer_id, customer_name, table_number, notes, status)
  values (auth.uid(), trim(p_customer_name), trim(p_table_number), nullif(trim(coalesce(p_notes,'')),''), 'pending_waiter')
  returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    select * into v_product
    from public.products
    where id = v_item->>'product_id' and active = true;
    if not found then raise exception 'Um dos produtos não está disponível.'; end if;
    v_quantity := (v_item->>'quantity')::integer;
    if v_quantity < 1 or v_quantity > 50 then raise exception 'Quantidade inválida.'; end if;
    insert into public.order_items(order_id,product_id,product_name,category,unit_price,quantity,notes,status)
    values (v_order_id,v_product.id,v_product.name,v_product.category,v_product.price,v_quantity,nullif(trim(coalesce(v_item->>'notes','')),''),'pending');
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.place_order(text,text,text,jsonb) to authenticated;
grant execute on function public.is_staff(text[]) to authenticated;

-- Segurança por função e por dono do pedido.
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Privilégios SQL; o RLS acima continua controlando quais linhas cada função pode acessar.
grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
grant select on public.products to authenticated;
grant select, insert, update on public.orders to authenticated;
grant select, insert, update on public.order_items to authenticated;

drop policy if exists profiles_read_own on public.profiles;
create policy profiles_read_own on public.profiles
for select to authenticated using (id = auth.uid());

drop policy if exists products_read_active on public.products;
create policy products_read_active on public.products
for select to authenticated using (active = true);

drop policy if exists orders_read_owner_or_staff on public.orders;
create policy orders_read_owner_or_staff on public.orders
for select to authenticated
using (customer_id = auth.uid() or public.is_staff(array['waiter','kitchen','admin']));

drop policy if exists orders_insert_customer on public.orders;
create policy orders_insert_customer on public.orders
for insert to authenticated
with check (customer_id = auth.uid() and status = 'pending_waiter');

drop policy if exists orders_update_staff on public.orders;
create policy orders_update_staff on public.orders
for update to authenticated
using (public.is_staff(array['waiter','kitchen','admin']))
with check (public.is_staff(array['waiter','kitchen','admin']));

drop policy if exists order_items_read_owner_or_staff on public.order_items;
create policy order_items_read_owner_or_staff on public.order_items
for select to authenticated
using (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid())
  or public.is_staff(array['waiter','kitchen','admin'])
);

drop policy if exists order_items_insert_order_owner on public.order_items;
create policy order_items_insert_order_owner on public.order_items
for insert to authenticated
with check (
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid())
);

drop policy if exists order_items_update_staff on public.order_items;
create policy order_items_update_staff on public.order_items
for update to authenticated
using (public.is_staff(array['waiter','kitchen','admin']))
with check (public.is_staff(array['waiter','kitchen','admin']));

-- Ativa atualizações em tempo real para as duas tabelas do fluxo de pedidos.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'order_items'
  ) then
    alter publication supabase_realtime add table public.order_items;
  end if;
end $$;

-- Depois de criar os usuários da equipe em Authentication → Users,
-- atribua a função correta, substituindo o e-mail:
-- update public.profiles set role = 'waiter'
-- where id = (select id from auth.users where email = 'garcom@seudominio.com');
--
-- Para cozinha, use role = 'kitchen'. Para um gerente, use role = 'admin'.
