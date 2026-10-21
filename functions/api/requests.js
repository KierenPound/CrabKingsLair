function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export async function onRequestPost(context) {
  const { request, env } = context;

  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY || !env.VIEW_REQUESTS_PASSWORD) {
    return jsonResponse({ error: 'Server is not configured.' }, 500);
  }

  let body;

  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }

  const password = String(body.password || '').trim();

  if (!password || password !== env.VIEW_REQUESTS_PASSWORD) {
    return jsonResponse({ error: 'Access denied.' }, 401);
  }

  const url = new URL('/rest/v1/requests', env.SUPABASE_URL);
  url.searchParams.set('select', 'id,card_name,name,artwork_type,notes,created_at');
  url.searchParams.set('order', 'created_at.desc');

  const response = await fetch(url.toString(), {
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      Accept: 'application/json',
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    return jsonResponse({ error: errorText || 'Could not load requests.' }, 500);
  }

  const data = await response.json();
  return jsonResponse({ data });
}
