
  select case
    when now() - updated_at < interval '4 hours' then 1.0
    when now() - updated_at < interval '8 hours' then 0.7
    when now() - updated_at < interval '12 hours' then 0.3
    else 0.1
  end;
