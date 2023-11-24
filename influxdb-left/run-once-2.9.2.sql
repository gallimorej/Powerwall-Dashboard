# DDL
# Powerwall-Dashboard v2.9.2
# 
# Version 2.9.2 Add support for additional Powerwalls (PW7 to PW12). This script renders the
# PW7 to PW12 data into the various long term buckets.
#
# Manual:
# docker exec --tty influxdb sh -c "influx -import -path=/var/lib/influxdb/run-once-2.9.2.sql"
#
# USE powerwall
CREATE DATABASE powerwall
# 
SELECT mean(PW7_temp) AS PW7_temp, mean(PW8_temp) AS PW8_temp, mean(PW9_temp) AS PW9_temp, mean(PW10_temp) AS PW10_temp, mean(PW11_temp) AS PW11_temp, mean(PW12_temp) AS PW12_temp INTO powerwall.pwtemps.:MEASUREMENT FROM (SELECT PW7_temp, PW8_temp, PW9_temp, PW10_temp, PW11_temp, PW12_temp FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
SELECT mean(PW7_PINV_Fout) AS PW7_PINV_Fout, mean(PW8_PINV_Fout) AS PW8_PINV_Fout, mean(PW9_PINV_Fout) AS PW9_PINV_Fout, mean(PW10_PINV_Fout) AS PW10_PINV_Fout, mean(PW11_PINV_Fout) AS PW11_PINV_Fout, mean(PW12_PINV_Fout) AS PW12_PINV_Fout INTO powerwall.vitals.:MEASUREMENT FROM (SELECT PW7_PINV_Fout, PW8_PINV_Fout, PW9_PINV_Fout, PW10_PINV_Fout, PW11_PINV_Fout, PW12_PINV_Fout  FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
SELECT mean(PW7_PINV_VSplit1) AS PW7_PINV_VSplit1, mean(PW8_PINV_VSplit1) AS PW8_PINV_VSplit1, mean(PW9_PINV_VSplit1) AS PW9_PINV_VSplit1, mean(PW10_PINV_VSplit1) AS PW10_PINV_VSplit1, mean(PW11_PINV_VSplit1) AS PW11_PINV_VSplit1, mean(PW12_PINV_VSplit1) AS PW12_PINV_VSplit1 INTO powerwall.vitals.:MEASUREMENT FROM (SELECT PW7_PINV_VSplit1, PW8_PINV_VSplit1, PW9_PINV_VSplit1, PW10_PINV_VSplit1, PW11_PINV_VSplit1, PW12_PINV_VSplit1  FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
SELECT mean(PW7_PINV_VSplit2) AS PW7_PINV_VSplit2, mean(PW8_PINV_VSplit2) AS PW8_PINV_VSplit2, mean(PW9_PINV_VSplit2) AS PW9_PINV_VSplit2, mean(PW10_PINV_VSplit2) AS PW10_PINV_VSplit2, mean(PW11_PINV_VSplit2) AS PW11_PINV_VSplit2, mean(PW12_PINV_VSplit2) AS PW12_PINV_VSplit2 INTO powerwall.vitals.:MEASUREMENT FROM (SELECT PW7_PINV_VSplit2, PW8_PINV_VSplit2, PW9_PINV_VSplit2, PW10_PINV_VSplit2, PW11_PINV_VSplit2, PW12_PINV_VSplit2  FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
SELECT mean(PW7_POD_nom_energy_remaining) AS PW7_POD_nom_energy_remaining, mean(PW8_POD_nom_energy_remaining) AS PW8_POD_nom_energy_remaining, mean(PW9_POD_nom_energy_remaining) AS PW9_POD_nom_energy_remaining, mean(PW10_POD_nom_energy_remaining) AS PW10_POD_nom_energy_remaining, mean(PW11_POD_nom_energy_remaining) AS PW11_POD_nom_energy_remaining, mean(PW12_POD_nom_energy_remaining) AS PW12_POD_nom_energy_remaining INTO powerwall.pod.:MEASUREMENT FROM (SELECT PW7_POD_nom_energy_remaining, PW8_POD_nom_energy_remaining, PW9_POD_nom_energy_remaining, PW10_POD_nom_energy_remaining, PW11_POD_nom_energy_remaining, PW12_POD_nom_energy_remaining FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
SELECT mean(PW7_POD_nom_full_pack_energy) AS PW7_POD_nom_full_pack_energy, mean(PW8_POD_nom_full_pack_energy) AS PW8_POD_nom_full_pack_energy, mean(PW9_POD_nom_full_pack_energy) AS PW9_POD_nom_full_pack_energy, mean(PW10_POD_nom_full_pack_energy) AS PW10_POD_nom_full_pack_energy, mean(PW11_POD_nom_full_pack_energy) AS PW11_POD_nom_full_pack_energy, mean(PW12_POD_nom_full_pack_energy) AS PW12_POD_nom_full_pack_energy INTO powerwall.pod.:MEASUREMENT FROM (SELECT PW7_POD_nom_full_pack_energy, PW8_POD_nom_full_pack_energy, PW9_POD_nom_full_pack_energy, PW10_POD_nom_full_pack_energy, PW11_POD_nom_full_pack_energy, PW12_POD_nom_full_pack_energy FROM powerwall.raw.http) GROUP BY time(1m), month, year fill(linear)
