/*
  # Enhance Reviews Table

  1. Add missing RLS policies to reviews table
  2. Add helpful votes functionality
  3. Add review images support

  1. New Tables
    - `review_votes`
      - `id` (uuid, primary key)
      - `review_id` (uuid, foreign key to reviews)
      - `user_id` (uuid, foreign key to profiles)
      - `is_helpful` (boolean)
      - `created_at` (timestamp)

  2. Enhancements to reviews table
    - Add `images` (text array for review images)
    - Add `verified_purchase` (boolean)
    - Add `helpful_count` (integer, default 0)

  3. Security
    - Enable RLS and add policies for reviews
    - Enable RLS and add policies for review_votes
*/

-- Add missing columns to reviews table
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'images') THEN
    ALTER TABLE reviews ADD COLUMN images text[] DEFAULT '{}';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'verified_purchase') THEN
    ALTER TABLE reviews ADD COLUMN verified_purchase boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'reviews' AND column_name = 'helpful_count') THEN
    ALTER TABLE reviews ADD COLUMN helpful_count integer DEFAULT 0 CHECK (helpful_count >= 0);
  END IF;
END $$;

-- Create review_votes table
CREATE TABLE IF NOT EXISTS review_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_helpful boolean NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Add RLS policies for reviews (if not already present)
CREATE POLICY "Anyone can read reviews"
  ON reviews
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Users can create reviews for purchased products"
  ON reviews
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.user_id = auth.uid()
      AND o.status = 'delivered'
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(o.items) AS item
        WHERE (item->>'product'->>'id')::uuid = reviews.product_id
      )
    )
  );

CREATE POLICY "Users can update their own reviews"
  ON reviews
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reviews"
  ON reviews
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Add RLS for review_votes
ALTER TABLE review_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read review votes"
  ON review_votes
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Users can manage their own review votes"
  ON review_votes
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create indexes
CREATE INDEX idx_review_votes_review_id ON review_votes(review_id);
CREATE INDEX idx_review_votes_user_id ON review_votes(user_id);
CREATE INDEX idx_reviews_verified_purchase ON reviews(verified_purchase);
CREATE INDEX idx_reviews_helpful_count ON reviews(helpful_count DESC);

-- Function to update helpful count
CREATE OR REPLACE FUNCTION update_review_helpful_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE reviews 
    SET helpful_count = (
      SELECT COUNT(*) 
      FROM review_votes 
      WHERE review_id = NEW.review_id AND is_helpful = true
    )
    WHERE id = NEW.review_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE reviews 
    SET helpful_count = (
      SELECT COUNT(*) 
      FROM review_votes 
      WHERE review_id = OLD.review_id AND is_helpful = true
    )
    WHERE id = OLD.review_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for helpful count
DROP TRIGGER IF EXISTS trigger_update_review_helpful_count ON review_votes;
CREATE TRIGGER trigger_update_review_helpful_count
  AFTER INSERT OR UPDATE OR DELETE ON review_votes
  FOR EACH ROW EXECUTE FUNCTION update_review_helpful_count();