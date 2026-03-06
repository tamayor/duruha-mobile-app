#!/bin/bash
export PGPASSWORD=postgres
psql -h localhost -p 54322 -U postgres -d postgres -c "\i '/Users/ellymartamayor/Documents/dirikita/dirikita-frontend/sql_functions/user functions/get_farmer_offer_by_id.sql'"
