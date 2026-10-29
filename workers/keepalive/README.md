# Supabase keep-alive

A Cloudflare Worker with a Cron Trigger that pings the Supabase projects behind
**CrabKingsLair** and **UnderCroft**, so neither is auto-paused for inactivity.

## Why this exists

Supabase pauses Free Plan projects after roughly a week of low activity. Their
docs define inactivity as *"too few user queries"* against the database, and
state that *"a few user requests to the database each day over the previous
week is enough"* to stay unpaused. A paused CrabKingsLair means the artwork
request form silently stops accepting submissions; a paused UnderCroft means
the app breaks.

Cloudflare was chosen over GitHub Actions because a GitHub scheduled workflow
is automatically disabled after 60 days of repository inactivity — exactly the
condition both of these repos are in. A Cloudflare Cron Trigger is not tied to
repository activity at all.

## Why not the usual `GET /rest/v1/` trick

Most keep-alive guides (and most AI-generated ones) tell you to hit the REST
root:

```
GET https://<project>.supabase.co/rest/v1/
```

That no longer works. Supabase now requires a **secret** API key for that
endpoint, so a publishable/anon key is rejected:

```json
{"message":"Secret API key required","hint":"Only secret API keys can be used for this endpoint."}
```

A workflow built on it fails every run without keeping anything alive.

## What actually works

A real (if trivial) query against a table:

```
GET https://<project>.supabase.co/rest/v1/<table>?select=id&limit=1
```

Both projects return `HTTP 200` with an empty body, `[]`. That empty array is
the point: RLS filters every row out, but PostgREST still executes a `SELECT`
against Postgres, which is what Supabase counts as activity. No new table and
no new RLS policy is required.

Tables used, and the only thing that would break this:

| Project | Table | Ping fails with 404 if |
| --- | --- | --- |
| CrabKingsLair | `requests` | the table is renamed |
| UnderCroft | `sections` | the table is renamed |

If either is ever renamed, update `TARGETS` in the Worker and redeploy. You can
also point the ping at a throwaway `keepalive` table with an anon `SELECT`
policy if you would rather not depend on a real one.

## The Worker

One Worker covers both projects — the cron fires once and pings each in parallel.

```js
// Supabase keep-alive — runs a trivial SELECT against each project so
// neither is auto-paused for a week of database inactivity.
// The publishable key is enough: RLS filters every row out, but the
// query still reaches Postgres, which is what counts.

const TARGETS = [
  { name: 'CrabKingsLair', urlVar: 'CKL_URL', keyVar: 'CKL_KEY', table: 'requests' },
  { name: 'UnderCroft',    urlVar: 'UC_URL',  keyVar: 'UC_KEY',  table: 'sections' },
];

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(pingAll(env));
  },

  // Visit the Worker URL in a browser to test on demand.
  async fetch(request, env) {
    const report = await pingAll(env);
    return new Response(report.join('\n') + '\n', {
      headers: { 'content-type': 'text/plain; charset=utf-8' },
    });
  },
};

async function pingAll(env) {
  return Promise.all(
    TARGETS.map(async ({ name, urlVar, keyVar, table }) => {
      const key = env[keyVar];
      const res = await fetch(`${env[urlVar]}/rest/v1/${table}?select=id&limit=1`, {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
      });
      return `${res.ok ? 'OK  ' : 'FAIL'} ${name.padEnd(13)} HTTP ${res.status}`;
    }),
  );
}
```

## Setup

The Worker is deployed from the Cloudflare dashboard. There are no files to
deploy and nothing to install, so it cannot drift from what is written here.

1. **dash.cloudflare.com** → **Workers & Pages** → **Create** → **Create Worker**.
2. Name it `supabase-keepalive` → **Deploy**.
3. **Edit code** → clear the template → paste the Worker above → **Deploy**.
4. **Settings** → **Variables and Secrets** → **Add**:

   | Name | Type | Value |
   | --- | --- | --- |
   | `CKL_URL` | Text | `https://khvydomhfyqhepkvcdsh.supabase.co` |
   | `UC_URL` | Text | `https://mpsygpgaakdtlgjzmbtr.supabase.co` |
   | `CKL_KEY` | Secret | the `anonKey` from `config.js` in this repo |
   | `UC_KEY` | Secret | See *UnderCroft key* below |

   Then **Deploy** again — variable changes do not apply until you redeploy.

5. **Settings** → **Triggers** → **Cron Triggers** → **Add** → `0 8 */3 * *`.

### UnderCroft key

The UnderCroft publishable key is deliberately gitignored in that project, so
it is not written here. Copy `SUPABASE_ANON_KEY` from:

```
~/Developer/UnderCroft/supabase_config.json
```

It is a publishable key, so it is RLS-limited and safe to store as a Cloudflare
secret — but it stays out of git by convention.

### Cron schedule

`0 8 */3 * *` runs at 08:00 UTC on days 1, 4, 7 … of the month. It is not
literally "every 3 days" — it resets at month boundaries — but the gap never
exceeds 3 days, which leaves ample margin inside the 7-day window. Change it to
`0 8 * * *` if you want daily activity instead.

## Verifying it works

Open the Worker URL in a browser:

```
https://supabase-keepalive.<your-subdomain>.workers.dev
```

```
OK   CrabKingsLair  HTTP 200
OK   UnderCroft     HTTP 200
```

Any `FAIL` line names the project and its HTTP status. That endpoint is public,
but it triggers two harmless `SELECT`s and never returns a key. If you would
rather not have a public endpoint at all, delete the `fetch` block from the
Worker after testing — the cron does not use it.

To watch the scheduled runs themselves, use **Logs** → **Live** in the Worker's
dashboard page.

## Restoring a paused project

Pausing loses no data. A paused project can be restored for up to a year from
**dash.supabase.com** → **Organizations** → select the paused project →
**Resume project**. The site simply breaks in the meantime, which is what this
Worker is here to prevent.
