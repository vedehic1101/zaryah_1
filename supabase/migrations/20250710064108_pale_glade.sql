/*
  # Add Coupons and Discounts System

  1. New Tables
    - `coupons`
      - `id` (uuid, primary key)
      - `code` (text, unique)
      - `description` (text)
      - `discount_type` (enum: percentage, fixed_amount)
      - `discount_value` (numeric)
      - `minimum_order_amount` (integer, in paise)
      - `maximum_discount_amount` (integer, in paise, nullable)
      - `usage_limit` (integer, nullable for unlimited)
      - `used_count` (integer, default 0)
      - `valid_from` (timestamp)
      - `valid_until` (timestamp)
      - `is_active` (boolean, default true)
      - `created_by` (uuid, foreign key to profiles)
      - `created_at` (timestamp)

    - `coupon_usage`
      - `id` (uuid, primary key)
      - `coupon_id` (uuid, foreign key to coupons)
      - `user_id` (uuid, foreign key to profiles)
      - `order_id` (uuid, foreign key to orders)
      - `discount_amount` (integer, in paise)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add appropriate policies
*/

-- Create enum for discount types
DO $$ BEGIN
  CREATE TYPE discount_type AS ENUM ('percentage', 'fixed_amount');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  description text NOT NULL,
  discount_type discount_type NOT NULL,
  discount_value numeric NOT NULL CHECK (discount_value > 0),
  minimum_order_amount integer DEFAULT 0 CHECK (minimum_order_amount >= 0),
  maximum_discount_amount integer CHECK (maximum_discount_amount IS NULL OR maximum_discount_amount > 0),
  usage_limit integer CHECK (usage_limit IS NULL OR usage_limit > 0),
  used_count integer DEFAULT 0 CHECK (used_count >= 0),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  CHECK (valid_until > valid_from),
  CHECK (discount_type = 'fixed_amount' OR (discount_type = 'percentage' AND discount_value <= 100))
);

CREATE TABLE IF NOT EXISTS coupon_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  discount_amount integer NOT NULL CHECK (discount_amount > 0),
  created_at timestamptz DEFAULT now(),
  UNIQUE(coupon_id, user_id, order_id)
);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;

-- Coupons policies
CREATE POLICY "Admins can manage all coupons"
  ON coupons
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

CREATE POLICY "Users can read active coupons"
  ON coupons
  FOR SELECT
  TO authenticated
  USING (is_active = true AND valid_from <= now() AND valid_until >= now());

-- Coupon usage policies
CREATE POLICY "Users can read their own coupon usage"
  ON coupon_usage
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can create coupon usage"
  ON coupon_usage
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can read all coupon usage"
  ON coupon_usage
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
  ));

CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_valid_dates ON coupons(valid_from, valid_until);
CREATE INDEX idx_coupons_is_active ON coupons(is_active);
CREATE INDEX idx_coupon_usage_coupon_id ON coupon_usage(coupon_id);
CREATE INDEX idx_coupon_usage_user_id ON coupon_usage(user_id);
CREATE INDEX idx_coupon_usage_order_id ON coupon_usage(order_id);