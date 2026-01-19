# Quick Reference: Snipe-IT Custom Fields

## Required Custom Fields for Secure Boot and BIOS Information

Add these three custom fields to your Snipe-IT instance to support the new Secure Boot and BIOS data collection:

**NOTE:** Fields 87, 88, and 89 are used to avoid conflicts with existing custom fields (41-86 are already in use for other purposes like Motherboard, PSU, CPU, RAM, etc.)

### Field 87: Secure Boot Status
```
Field Name: Secure Boot Status
DB Field: _snipeit_secure_boot_status_87
Field Type: Text
Format: Single Line Text
Help Text: Current Secure Boot status (Enabled/Disabled/Not Supported)
Required: No
Fieldsets: Computers
```

**Example Values:**
- `Enabled`
- `Disabled`
- `Not Supported (Legacy BIOS)`
- `Unknown`

---

### Field 88: Secure Boot Certificate Expiry
```
Field Name: Secure Boot Certificate Expiry
DB Field: _snipeit_secure_boot_cert_expiry_88
Field Type: Textarea
Format: Multi-line Text
Help Text: Secure Boot certificate expiration dates with status indicators
Required: No
Fieldsets: Computers
```

**Example Value:**
```
Microsoft Corporation UEFI CA 2011 : 2026-06-30 (EXPIRING SOON, 165 days)
Microsoft Windows Production PCA 2011 : 2026-10-30 (Valid, 287 days)
```

**Status Indicators:**
- `EXPIRED` - Certificate has expired
- `EXPIRING SOON` - Less than 180 days until expiry
- `Valid` - More than 180 days until expiry

---

### Field 89: BIOS Release Date
```
Field Name: BIOS Release Date
DB Field: _snipeit_bios_release_date_89
Field Type: Text (or Date if you prefer)
Format: YYYY-MM-DD
Help Text: Date when the BIOS firmware was released
Required: No
Fieldsets: Computers
```

**Example Value:**
- `2023-05-15`

---

## How to Add These Fields in Snipe-IT

1. Log in as administrator
2. Go to **Settings** → **Custom Fields**
3. Click **Create New**
4. Fill in the details from above
5. Save each field
6. Add all three fields to your "Computers" fieldset (or appropriate fieldset)
7. Associate fieldset with your asset models

## Important Notes

- The field numbers (87, 88, 89) are used in the script to map data to Snipe-IT
- These numbers were chosen to avoid conflicts with existing fields 1-86
- If your Snipe-IT instance uses different field numbers, update the script accordingly
- Certificate information requires administrator privileges to collect
- Legacy BIOS systems will show "Not Supported" for Secure Boot status
- Empty BIOS release dates indicate the BIOS doesn't report this information

## Existing Field Numbers (DO NOT USE)

The following field numbers are already in use (as of this implementation):
- Fields 1-86: Various existing fields including MAC Address, CPU, RAM, FQDN, OS, BIOS, Graphics, Storage, Motherboard, PSU, etc.
- Fields 87-89: **NEW** - Secure Boot and BIOS information (this implementation)

## Verifying the Setup

After creating the fields and deploying the updated script:

1. Run the script on a test machine
2. Check the asset in Snipe-IT
3. Verify all three fields are populated with data
4. Review logs for any warnings about expiring certificates

## Support

For detailed setup instructions, see [SECURE_BOOT_SETUP.md](SECURE_BOOT_SETUP.md)
