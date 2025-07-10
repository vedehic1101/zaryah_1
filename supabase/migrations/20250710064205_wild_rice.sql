/*
  # Add Inventory Management

  1. Add inventory columns to products table
    - `stock_quantity` (integer, default 0)
    - `low_stock_threshold` (integer, default 5)
    - `track_inventory` (boolean, default true)

  2. New Tables
    - `inventory_movements`
      - `id` (uuid, primary key)
      - `product_id` (uuid, foreign key to products)
      - `movement_type` (enum: sale, restock, adjustment, return)
      - `quantity` (integer, can be negative for outgoing)
      - `reason` (text)
      - `order_id` (uuid, foreign key to orders, nullable)
      - `created_by` (uuid, foreign key to profiles)
      - `created_at` (timestamp)

  3. Security
    - Enable RLS and add appropriate policies
*/

-- Add inventory columns to products table
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'stock_quantity') THEN
    ALTER TABLE products ADD COLUMN stock_quantity integer DEFAULT 0 CHECK (stock_quantity >= 0);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'low_stock_threshold') THEN
    ALTER TABLE products ADD COLUMN low_stock_threshold integer DEFAULT 5 CHECK (low_stock_threshold >= 0);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'track_inventory') THEN
    ALTER TABLE products ADD COLUMN track_inventory boolean DEFAULT true;
  END IF;
END $$;

-- Create enum for movement types
DO $$ BEGIN
  CREATE TYPE inventory_movement_type AS ENUM ('sale', 'restock', 'adjustment', 'return');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  movement_type inventory_movement_type NOT NULL,
  quantity integer NOT NULL,
  reason text,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can read movements for their products"
  ON inventory_movements
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM products p
      WHERE p.id = inventory_movements.product_id 
      AND p.seller_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Sellers can create movements for their products"
  ON inventory_movements
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM products p
      WHERE p.id = inventory_movements.product_id 
      AND p.seller_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE INDEX idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_created_at ON inventory_movements(created_at DESC);
CREATE INDEX idx_inventory_movements_order_id ON inventory_movements(order_id);

-- Function to update stock quantity
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products 
  SET stock_quantity = stock_quantity + NEW.quantity
  WHERE id = NEW.product_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for stock updates
DROP TRIGGER IF EXISTS trigger_update_product_stock ON inventory_movements;
CREATE TRIGGER trigger_update_product_stock
  AFTER INSERT ON inventory_movements
  FOR EACH ROW EXECUTE FUNCTION update_product_stock();