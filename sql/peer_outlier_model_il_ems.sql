WITH enriched_claims AS (
  SELECT
    npi,
    nppes_provider_last_org_name AS provider,
    provider_type,
    nppes_provider_state AS state,
    hcpcs_code,
    bene_day_srvc_cnt AS service_volume,
    average_submitted_chrg_amt,
    average_medicare_allowed_amt,
    -- Individual provider multipliers (provider billed vs Medicare allowable limits)
    SAFE_DIVIDE(average_submitted_chrg_amt, average_medicare_allowed_amt) AS provider_billing_multiplier
  FROM `bigquery-public-data.cms_medicare.physicians_and_other_supplier_2015`
  WHERE
    nppes_provider_state = 'IL'
    AND average_medicare_allowed_amt > 0
    AND provider_type = 'Ambulance Service Supplier'
),
peer_group_benchmarks AS (
  SELECT
    *,
    -- Calculate peer group median charge per HCPCS code (filtered, IL from enriched_claims)
    PERCENTILE_CONT(average_submitted_chrg_amt, 0.5) OVER(
      PARTITION BY hcpcs_code, provider_type, state
    ) AS peer_median_submitted_chrg,
    -- Establish p90 threshold for billing multipliers in this group
    PERCENTILE_CONT(provider_billing_multiplier, 0.90) OVER(
      PARTITION BY hcpcs_code, provider_type, state
    ) AS peer_p90_multiplier
  FROM enriched_claims
)
SELECT
  npi,
--  provider,
--  provider_type,
  hcpcs_code,
  service_volume,
  ROUND(average_submitted_chrg_amt, 2) AS submitted_charge,
  ROUND(peer_median_submitted_chrg, 2) AS peer_median_charge,
  ROUND(average_medicare_allowed_amt, 2) AS medicare_allowed,
  ROUND(provider_billing_multiplier, 2) AS billing_multiplier,
  ROUND(peer_p90_multiplier, 2) AS peer_p90_threshold,
  CASE
    WHEN provider_billing_multiplier >= (peer_p90_multiplier * 1.5) THEN 'Critical Risk'
    ELSE 'High Risk (P90)'
  END AS risk_tier
FROM peer_group_benchmarks
WHERE
  provider_billing_multiplier >= peer_p90_multiplier
ORDER BY
  billing_multiplier DESC;
