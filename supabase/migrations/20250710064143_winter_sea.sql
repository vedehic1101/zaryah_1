/*
  # Add Seller Analytics and Performance Tracking

  1. New Tables
    - `seller_analytics`
      - `id` (uuid, primary key)
      - `seller_id` (uuid, foreign key to profiles)
      - `date` (date)
      - `total_views` (integer, default 0)
      - `total_orders` (integer, default 0)
      - `total_revenue` (integer, default 0, in paise)
      - `conversion_rate` (numeric, default 0)
      - `average_rating` (numeric, default 0)
      - `total_reviews` (integer, default 0)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `seller_analytics` table
    - Add policies for sellers to view their own analytics
*/

CREATE TABLE IF NOT EXISTS seller_analytics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date date NOT NULL,
  total_views integer DEFAULT 0 CHECK (total_views >= 0),
  total_orders integer DEFAULT 0 CHECK (total_orders >= 0),
  total_revenue integer DEFAULT 0 CHECK (total_revenue >= 0),
  conversion_rate numeric DEFAULT 0 CHECK (conversion_rate >= 0 AND conversion_rate <= 100),
  average_rating numeric DEFAULT 0 CHECK (average_rating >= 0 AND average_rating <= 5),
  total_reviews integer DEFAULT 0 CHECK (total_reviews >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(seller_id, date)
);

ALTER TABLE seller_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can read their own analytics"
  ON seller_analytics
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = seller_id OR
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "System can manage analytics"
  ON seller_analytics
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE INDEX idx_seller_analytics_seller_id ON seller_analytics(seller_id);
CREATE INDEX idx_seller_analytics_date ON seller_analytics(date DESC);
CREATE INDEX idx_seller_analytics_seller_date ON seller_analytics(seller_id, date DESC);

-- Create trigger for updated_at
CREATE TRIGGER update_seller_analytics_updated_at
  BEFORE UPDATE ON seller_analytics
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();