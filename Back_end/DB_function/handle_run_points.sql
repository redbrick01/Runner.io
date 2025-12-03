BEGIN
  -- Insert into point_history
  INSERT INTO public.point_history (event_type, points_delta, created_at, user_id)
  VALUES ('run_created', NEW.point, now(), NEW.user_id);

  -- Update profiles.total_points safely
  UPDATE public.profiles
  SET total_points = COALESCE(total_points, 0) + COALESCE(NEW.point, 0)
  WHERE user_id = NEW.user_id;

  RETURN NEW;
END;