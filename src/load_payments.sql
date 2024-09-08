drop table if exists raw_payments;

.mode csv
.import payments_latest.csv raw_payments
