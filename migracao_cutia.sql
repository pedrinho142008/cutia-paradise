BEGIN;

-- ==========================================
-- CUTIA PARADISE | MIGRACAO SEGURA
-- ==========================================

-- 1. CAMPOS DAS COMANDAS

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS command_type text,
  ADD COLUMN IF NOT EXISTS identification text,
  ADD COLUMN IF NOT EXISTS command_status text,
  ADD COLUMN IF NOT EXISTS opened_at timestamptz,
  ADD COLUMN IF NOT EXISTS closed_total numeric(10,2),
  ADD COLUMN IF NOT EXISTS payment_method text;

-- Preserva os dados de abertura já existentes.
UPDATE public.orders
SET
  command_type = COALESCE(command_type, 'Mesa'),
  identification = COALESCE(identification, table_number),
  command_status = COALESCE(
    command_status,
    CASE WHEN closed_at IS NOT NULL THEN 'closed' ELSE 'open' END
  ),
  opened_at = COALESCE(opened_at, created_at);

ALTER TABLE public.orders
  ALTER COLUMN command_type SET DEFAULT 'Mesa',
  ALTER COLUMN command_type SET NOT NULL,
  ALTER COLUMN identification SET NOT NULL,
  ALTER COLUMN command_status SET DEFAULT 'open',
  ALTER COLUMN command_status SET NOT NULL,
  ALTER COLUMN opened_at SET DEFAULT now(),
  ALTER COLUMN opened_at SET NOT NULL;

-- 2. CAMPOS DOS ITENS E DA COZINHA

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS kitchen_status text;

ALTER TABLE public.order_items
  ALTER COLUMN kitchen_confirmation SET DEFAULT 'pending';

UPDATE public.order_items
SET kitchen_confirmation = 'pending'
WHERE kitchen_confirmation IS NULL;

UPDATE public.order_items
SET kitchen_status = CASE
  WHEN status = 'preparing' THEN 'preparing'
  WHEN status = 'ready' THEN 'ready'
  WHEN status = 'delivered' THEN 'delivered'
  ELSE 'waiting'
END
WHERE kitchen_status IS NULL;

ALTER TABLE public.order_items
  ALTER COLUMN kitchen_status SET DEFAULT 'waiting',
  ALTER COLUMN kitchen_status SET NOT NULL;

-- 3. RESTRICOES DOS NOVOS ESTADOS

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_command_type_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_command_type_check
      CHECK (command_type IN ('Mesa', 'Lugar'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_command_status_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_command_status_check
      CHECK (command_status IN ('open', 'closed'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'order_items_confirmation_check'
  ) THEN
    ALTER TABLE public.order_items
      ADD CONSTRAINT order_items_confirmation_check
      CHECK (kitchen_confirmation IN ('pending', 'confirmed', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'order_items_kitchen_status_check'
  ) THEN
    ALTER TABLE public.order_items
      ADD CONSTRAINT order_items_kitchen_status_check
      CHECK (kitchen_status IN ('waiting', 'preparing', 'ready', 'delivered'));
  END IF;
END $$;

-- 4. INDICES

CREATE INDEX IF NOT EXISTS orders_command_status_idx
  ON public.orders(command_status);

CREATE INDEX IF NOT EXISTS orders_opened_at_idx
  ON public.orders(opened_at);

CREATE INDEX IF NOT EXISTS order_items_kitchen_status_idx
  ON public.order_items(kitchen_status);

CREATE INDEX IF NOT EXISTS order_items_confirmation_idx
  ON public.order_items(kitchen_confirmation);

-- 5. CATALOGO COMPLETO

INSERT INTO public.products
(id, name, category, description, price, sort_order)
VALUES
('heineken-long-neck','Heineken long neck','Cervejas',NULL,11,1),
('budweiser-long-neck','Budweiser long neck','Cervejas',NULL,10,2),
('itaipava-lata','Itaipava lata','Cervejas',NULL,5,3),
('devassa-lata','Devassa lata','Cervejas',NULL,5,4),
('pitu-limao','Pitú limão','Cervejas',NULL,10,5),
('caranguejo-prata','Caranguejo Prata lata','Cervejas',NULL,10,6),
('cerveja-malzbier','Cerveja Malzbier','Cervejas',NULL,6,7),

('coca-cola-lata','Coca-Cola lata','Refrigerantes',NULL,6,8),
('coca-zero-lata','Coca Zero lata','Refrigerantes',NULL,6,9),
('guarana-lata','Guaraná lata','Refrigerantes',NULL,6,10),
('coca-cola-1l','Coca-Cola 1L','Refrigerantes',NULL,12,11),
('pepsi-1l','Pepsi 1L','Refrigerantes',NULL,10,12),
('guarana-1l','Guaraná 1L','Refrigerantes',NULL,10,13),

('cachaca','Cachaça','Doses',NULL,3,14),
('conhaque','Conhaque','Doses',NULL,5,15),

('caipirinha-tradicional','Caipirinha tradicional','Drinks',NULL,10,16),
('caipirinha-cremosa','Caipirinha cremosa','Drinks',NULL,12,17),
('caipifruta','Caipifruta','Drinks',NULL,12,18),

('suco-maracuja','Maracujá','Sucos naturais',NULL,8,19),
('suco-goiaba','Goiaba','Sucos naturais',NULL,6,20),
('suco-acerola','Acerola','Sucos naturais',NULL,6,21),
('suco-limao','Limão','Sucos naturais',NULL,6,22),
('suco-laranja','Laranja','Sucos naturais',NULL,8,23),

('camarao-alho-oleo','Camarão alho e óleo','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',80,24),
('camarao-crocante','Camarão crocante','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',90,25),
('file-fritas','Filé com fritas','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,26),
('frango-crocante','Frango crocante','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,27),
('frango-passarinha','Frango à passarinha','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',60,28),
('calabresa-acebolada','Calabresa acebolada','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',45,29),
('peixe-frito','Peixe frito','Petiscos','Acompanha batatinha ou macaxeira frita e salada.',80,30),

('galinha-caipira','Galinha caipira completa','Refeições','Feijão verde, arroz, macarrão, pirão, farofa e vinagrete.',180,31),
('executivo-4','Prato executivo para 4 pessoas','Refeições',NULL,100,32),
('executivo-2','Prato executivo para 2 pessoas','Refeições',NULL,50,33),
('prato-feito','Prato feito','Refeições',NULL,20,34),

('caldo-camarao','Caldo de camarão','Caldos',NULL,15,35),
('caldo-sertanejo','Caldo sertanejo','Caldos',NULL,15,36),
('caldo-mocoto','Caldo de mocotó','Caldos',NULL,15,37),
('caldo-polvo','Caldo de polvo','Caldos',NULL,15,38),

('batatinha-frita','Batatinha frita','Entradas e porções',NULL,20,39),
('macaxeira-frita','Macaxeira frita','Entradas e porções',NULL,20,40),
('mini-pastel','Mini pastel (8 unidades)','Entradas e porções',NULL,20,41),
('pastel-tradicional','Pastel tradicional','Entradas e porções',NULL,8,42),
('macarrao','Macarrão','Entradas e porções',NULL,10,43),
('arroz','Arroz','Entradas e porções',NULL,10,44),
('salada','Salada','Entradas e porções',NULL,5,45),
('bolinho-macaxeira','Bolinho de macaxeira','Entradas e porções',NULL,6,46),
('tapioca-recheada','Tapioca recheada','Entradas e porções',NULL,12,47)

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  sort_order = EXCLUDED.sort_order;

-- 6. PERMISSOES DE EXCLUSAO DE ITENS
-- Só permite excluir itens ainda não iniciados,
-- que estejam aguardando ou tenham sido recusados.

DROP POLICY IF EXISTS staff_delete_items
  ON public.order_items;

CREATE POLICY staff_delete_items
ON public.order_items
FOR DELETE
TO authenticated
USING (
  public.is_staff()
  AND kitchen_status = 'waiting'
  AND kitchen_confirmation IN ('pending', 'rejected')
);

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.order_items TO authenticated;

GRANT SELECT, INSERT, UPDATE
ON public.orders TO authenticated;

GRANT SELECT
ON public.products TO authenticated;

-- 7. REALTIME

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'orders'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'order_items'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.order_items;
    END IF;
  END IF;
END $$;

COMMIT;
