# rename table
RENAME TABLE histories TO histories_old;

# create new histories table with id as primary key
create table histories (
    id  int(10) unsigned not null AUTO_INCREMENT,
    package        VARCHAR(100) NOT NULL,
    summary        text NOT NULL,
    checks         text,
    check_details  text,
    date_updated   datetime NOT NULL,
    primary key (id)
);

# move data from old table into new table
SET AUTOCOMMIT = 0; SET UNIQUE_CHECKS=0; SET FOREIGN_KEY_CHECKS=0;
ALTER TABLE histories CONVERT TO CHARACTER SET utf8;
INSERT INTO histories (package,summary,checks,check_details,date_updated) SELECT package,summary,checks,check_details,date_updated FROM histories_old;
# maybe can do above but with only data from last 30 days?
    -- INSERT INTO histories (package,summary,checks,check_details,date_updated) 
    -- SELECT package,summary,checks,check_details,date_updated 
    -- FROM histories_old
    -- WHERE date_updated > NOW() - INTERVAL 1 MONTH;
SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; COMMIT; SET AUTOCOMMIT = 1;

# create multi-column index to speed up queries
CREATE INDEX pkg_date ON histories (package,date_updated);

# get deets
describe cchecks.histories;
show index from histories;
# this should be very fast if it worked
select count(*) from histories;

# test some queries - should be fast
select package,date_updated from histories where DATE(date_updated) = '2019-09-05' limit 10;
# to file
select * INTO OUTFILE '2019-06-01.txt'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
from histories
where DATE(date_updated) = '2019-06-01';

select package,summary,check_details,date_updated INTO OUTFILE '2019-06-01-nochecks.txt'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
from histories
where DATE(date_updated) = '2019-06-01';

# drop old table
DROP TABLE histories_old;
