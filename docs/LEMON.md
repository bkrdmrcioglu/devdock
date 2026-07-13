# Lemon Squeezy — payment setup for DevDock

You do **not** put card forms inside the Mac app. Lemon hosts checkout; DevDock unlocks Pro with a **license key**.

## Flow

```
Customer → Buy Pro on Lemon (browser)
         → Receives license key by email
         → DevDock → Settings → paste key → Activate
         → Lemon License API confirms → Pro unlocked
```

## Dashboard checklist

1. Create product **DevDock Pro** ($29 one-time recommended)
2. Variant → enable **License keys**
3. Confirmation email includes the key (default)
4. Copy checkout / store URL → put in app as `LicenseLimits.buyURL`  
   (currently `https://devdock.lemonsqueezy.com`)
5. Website field for verification: your GitHub Pages landing

## App side (already implemented)

- Free: max 3 projects, no workspaces
- Settings → Activate Pro / Buy Pro / Deactivate
- Calls public Lemon endpoints:
  - `POST /v1/licenses/activate`
  - `POST /v1/licenses/validate`
  - `POST /v1/licenses/deactivate`
- No Lemon **API secret** is embedded in the app (correct for a desktop client)

## Test mode

Use Lemon **Test mode** + a test license key before going live.

## What you do manually

1. Finish Lemon identity verification  
2. Create Pro product + license keys  
3. Update `buyURL` if your store slug differs  
4. Publish landing + point Lemon “Your website” to it  
```
