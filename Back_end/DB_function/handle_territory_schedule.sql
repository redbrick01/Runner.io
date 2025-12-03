BEGIN
  -- updated_at이 변경되었을 때만 next_process_at 갱신
  IF NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN
    NEW.next_process_at := NEW.updated_at + interval '30 minutes';
  END IF;

  RETURN NEW;
END;