# Cloud-Scale Provider Peer Outlier Detection for Medical Claims Waste & Abuse

## Executive Summary
Healthcare fraud, waste, and abuse (FWA) has the potential to cost payers billions in overpayments. Rule-based auditing systems may evaluate provider claim submissions on a static threshold not accounting for variations in cost or frequency for regional cost variations.

This project builds a dynamic, scalable **Peer Group Outlier Model** using **Google BigQuery SQL**. Utilizing window functions to partition data by provider type, state, and HCPCS code, the model automatically picks out high-risk billing anomalies and top 10% outliers without manual pre-filtering.

---

## 1. Technical Architecture & Stack
* **Data Warehouse:** Google BigQuery
* **Language/Query Standard:** Standard SQL
* **Key SQL Concepts:** Window Functions (`PERCENTILE_CONT`), Partitions (`PARTITION BY`), Safe Arithmetic (`SAFE_DIVIDE`), and Conditional Risk Tiers (`CASE WHEN`).
* **Dataset:** CMS Medicare Provider Utilization and Payment Data (`physician_and_other_supplier_2015`) filtered for Illinois providers (all HCPCS service codes).

---

## 2. Methodology & Discovery Steps
1. **Ingestion & Scoping:** Loaded public CMS Medicare utilization data set from BigQuery public datasets and isolated for Illinois providers (all providers in this sample, can be filtered by provider type or HCPCS codes for more narrow scope).
2. **Feature Engineering:** Calculated individual provider **Billing Multiplier** by evaluating submitted charges against standard Medicare allowable amounts.
3. **Contextual Peer Grouping:** Instead of a flat national baseline, partitioned providers by `state` to establish true local peer baselines and medians. For a more narrow region, cities or zip code ranges could be isolated into "regions" and compared against one another. For Illinois, this could include "Chicago & Metro" and "Rural."
4. **P90 Percentile Isolation:** Utilized continuous distribution percentile functions (`PERCENTILE_CONT`) to map out the exact **P90 threshold** for each peer cluster, flagging providers billing significantly higher than their local peers.
5. **Risk Stratification:** Categorized outputs into **High Risk (P90)** and **Critical Risk** tiers to help investigation teams prioritize high-yield audit targets.

---

## 3. Code Preview
The core logic utilizes advanced window functions in BigQuery:

```sql
PERCENTILE_CONT(provider_billing_multiplier, 0.90) OVER(
  PARTITION BY hcpcs_code, provider_type, state
) AS peer_p90_multiplier
