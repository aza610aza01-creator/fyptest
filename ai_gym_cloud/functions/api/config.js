export async function onRequestGet(context) {
  const { env } = context;
  return new Response(
    JSON.stringify({
      app: "AI Gym Cloud v5.2",
      platform: "Cloudflare Pages Edge",
      supabaseUrl: env.SUPABASE_URL || "https://eprmvrtcpuydxhtzwfep.supabase.co",
      supabasePublishableKey:
        env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_7psvpRTKPvrcIFZjNcynIQ_KiDD5lgP",
      smtpBuildDomain: env.SMTP_BUILD_DOMAIN || "aigymcloud.build",
      otpVerifyCodeEnabled: true,
      otpLength: 6
    }),
    {
      headers: {
        "content-type": "application/json;charset=UTF-8",
        "cache-control": "no-store"
      }
    }
  );
}
