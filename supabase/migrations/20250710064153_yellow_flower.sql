/*
  # Add Product Categories Management

  1. New Tables
    - `product_categories`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `description` (text)
      - `parent_id` (uuid, foreign key to product_categories, nullable for top-level)
      - `image_url` (text, nullable)
      - `is_active` (boolean, default true)
      - `sort_order` (integer, default 0)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `product_categories` table
    - Add policies for public read access and admin management
*/

CREATE TABLE IF NOT EXISTS product_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text,
  parent_id uuid REFERENCES product_categories(id) ON DELETE SET NULL,
  image_url text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active categories"
  ON product_categories
  FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage all categories"
  ON product_categories
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

CREATE INDEX idx_product_categories_parent_id ON product_categories(parent_id);
CREATE INDEX idx_product_categories_is_active ON product_categories(is_active);
CREATE INDEX idx_product_categories_sort_order ON product_categories(sort_order);

-- Create trigger for updated_at
CREATE TRIGGER update_product_categories_updated_at
  BEFORE UPDATE ON product_categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default categories
INSERT INTO product_categories (name, description, sort_order) VALUES
  ('Jewelry', 'Handcrafted jewelry and accessories', 1),
  ('Home Decor', 'Beautiful items for your home', 2),
  ('Art', 'Artistic creations and paintings', 3),
  ('Textiles', 'Handwoven fabrics and clothing', 4),
  ('Candles', 'Scented and decorative candles', 5),
  ('Pottery', 'Ceramic and clay items', 6),
  ('Accessories', 'Fashion and lifestyle accessories', 7),
  ('Bags', 'Handmade bags and purses', 8),
  ('Toys', 'Handcrafted toys for children', 9),
  ('Stationery', 'Paper goods and writing materials', 10)
ON CONFLICT (name) DO NOTHING;