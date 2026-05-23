# `run-history`

Supabase Edge Function reference implementation for returning the current
authenticated user's running history from `public.runs`.

## Request

- Method: `GET`
- Query:
  - `limit` default `50`, max `100`
  - `offset` default `0`
- Header:
  - `Authorization: Bearer <access_token>`

## Response

```json
{
  "items": [
    {
      "id": 1,
      "started_at": "2025-01-01T09:00:00",
      "ended_at": "2025-01-01T09:30:00",
      "duration": 1800,
      "distance": 5000,
      "created_at": "2025-01-01T09:30:05Z",
      "user_id": "uuid",
      "point": 65.5,
      "avg_pace": 360,
      "calories": 320,
      "area": 0,
      "path_geom": "LINESTRING(...)",
      "loop_geom": null
    }
  ],
  "paging": {
    "limit": 50,
    "offset": 0,
    "count": 1,
    "total": 1,
    "has_more": false
  }
}
```

## Notes

- This implementation uses `SUPABASE_SERVICE_ROLE_KEY` for the data query after
  verifying the caller with the incoming JWT.
- Current DB schema does not include `route_points` in `public.runs`.
- For map rendering fallback, this function returns `loop_geom` and `path_geom`.
