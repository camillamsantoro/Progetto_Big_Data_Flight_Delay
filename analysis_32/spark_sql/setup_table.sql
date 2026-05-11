create database if not exists flights_project;
drop table if exists flights_project.flights;

create external table if not exists flights_project.flights (
    month bigint,
    fl_date timestamp,
    op_unique_carrier string,
    op_carrier_fl_num double,
    origin string,
    dest string,
    dep_delay double,
    arr_delay double,
    cancelled bigint,
    cancellation_code string,
    carrier_delay bigint,
    weather_delay bigint,
    nas_delay bigint,
    security_delay bigint,
    late_aircraft_delay bigint
)
row format delimited
fields terminated by ','
stored as textfile
location '${hiveconf:DATA_PATH}'
tblproperties("skip.header.line.count"="1");