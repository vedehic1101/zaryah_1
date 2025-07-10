/*
  # Add Product Views Tracking

  1. New Tables
    - `product_views`
      - `id` (uuid, primary key)
      - `product_id` (uuid, foreign key to products)
      - `user_id` (uuid, foreign key to profiles, nullable for anonymous views)
      - `ip_address` (text, for anonymous tracking)
      - `user_agent` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `product_views` table
    - Add policies for tracking views
*/

CREATE TABLE IF NOT EXISTS product_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can create product views"
  ON product_views
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Users can read their own views"
  ON product_views
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all views"
  ON product_views
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

CREATE INDEX idx_product_views_product_id ON product_views(product_id);
CREATE INDEX idx_product_views_user_id ON product_views(user_id);
CREATE INDEX idx_product_views_created_at ON product_views(created_at DESC);