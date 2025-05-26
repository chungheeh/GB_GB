-- Add points column to profiles table if it doesn't exist
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0 NOT NULL;

-- Create point_history table
CREATE TABLE IF NOT EXISTS public.point_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL,
  type TEXT CHECK (type IN ('EARN', 'USE')) NOT NULL,
  description TEXT NOT NULL,
  related_answer_id UUID REFERENCES public.answers(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for point_history table
CREATE INDEX IF NOT EXISTS point_history_user_id_idx ON public.point_history(user_id);
CREATE INDEX IF NOT EXISTS point_history_type_idx ON public.point_history(type);
CREATE INDEX IF NOT EXISTS point_history_created_at_idx ON public.point_history(created_at);

-- Enable RLS for point_history table
ALTER TABLE public.point_history ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for point_history
CREATE POLICY "Users can view their own point history"
  ON public.point_history FOR SELECT
  USING (auth.uid() = user_id);

-- Create function for adding points to user
CREATE OR REPLACE FUNCTION public.add_points(
  p_user_id UUID,
  p_amount INTEGER,
  p_description TEXT,
  p_related_answer_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Update user's points
  UPDATE public.profiles
  SET points = points + p_amount
  WHERE id = p_user_id;
  
  -- Record point history
  INSERT INTO public.point_history (
    user_id,
    amount,
    type,
    description,
    related_answer_id,
    created_at
  ) VALUES (
    p_user_id,
    p_amount,
    'EARN',
    p_description,
    p_related_answer_id,
    NOW()
  );
  
  -- Return success
  SELECT jsonb_build_object(
    'success', true,
    'message', '포인트가 성공적으로 추가되었습니다.',
    'points_added', p_amount
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error information
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', SQLSTATE
    );
END;
$$;

-- Create function for using points
CREATE OR REPLACE FUNCTION public.use_points(
  p_user_id UUID,
  p_amount INTEGER,
  p_description TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_points INTEGER;
  v_result JSONB;
BEGIN
  -- Get current points
  SELECT points INTO v_current_points
  FROM public.profiles
  WHERE id = p_user_id;
  
  -- Check if user has enough points
  IF v_current_points < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', '포인트가 부족합니다.',
      'available_points', v_current_points,
      'required_points', p_amount
    );
  END IF;
  
  -- Update user's points
  UPDATE public.profiles
  SET points = points - p_amount
  WHERE id = p_user_id;
  
  -- Record point history
  INSERT INTO public.point_history (
    user_id,
    amount,
    type,
    description,
    created_at
  ) VALUES (
    p_user_id,
    p_amount,
    'USE',
    p_description,
    NOW()
  );
  
  -- Return success
  SELECT jsonb_build_object(
    'success', true,
    'message', '포인트가 성공적으로 사용되었습니다.',
    'points_used', p_amount,
    'remaining_points', v_current_points - p_amount
  ) INTO v_result;
  
  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error information
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', SQLSTATE
    );
END;
$$;

-- Grant permissions
GRANT ALL ON public.point_history TO postgres, service_role;
GRANT SELECT ON public.point_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_points TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_points TO authenticated; 