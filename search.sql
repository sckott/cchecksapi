# first try, didn't work, couldn't query on deets and checks/check_details didn't support FULLTEXT
ALTER TABLE histories ADD FULLTEXT INDEX `deets` (checks, check_details);
show index from histories;
ALTER TABLE histories DROP INDEX deets;

# next try
ALTER TABLE histories ADD FULLTEXT (check_details);
show index from histories;

# query
SELECT package,check_details FROM histories WHERE MATCH(check_details) AGAINST('memory') limit 3;
SELECT package,check_details FROM histories WHERE MATCH(check_details) AGAINST('memory' IN BOOLEAN MODE) limit 3;
SELECT package,check_details FROM histories WHERE MATCH(check_details) AGAINST('app*' IN BOOLEAN MODE) limit 5;
# return relevance score
SELECT check_details,MATCH(check_details) AGAINST('memory') AS relevance 
  FROM histories WHERE MATCH(check_details) AGAINST('memory') limit 3;





# with both checks, check_details and summary
ALTER TABLE histories ADD FULLTEXT (check_details); # just add this one
-- ALTER TABLE histories ADD FULLTEXT (checks);
-- ALTER TABLE histories ADD FULLTEXT (summary);
show index from histories;
-- ALTER TABLE histories DROP INDEX checks;
-- ALTER TABLE histories DROP INDEX summary;

# query
SELECT package,summary FROM histories WHERE MATCH(check_details) AGAINST('memory') AND package = "bench" limit 3;
SELECT package,summary FROM histories WHERE MATCH(summary) AGAINST('any:true') limit 3;
SELECT package,summary FROM histories WHERE MATCH(summary) AGAINST('any:false') limit 3;
SELECT package,summary FROM histories WHERE MATCH(summary) AGAINST('error*1' IN BOOLEAN MODE) limit 3;


# try to select first record of each package matching a FULLTEXT query
SELECT package,summary FROM histories GROUP BY package;
SELECT package,date_updated FROM histories WHERE MATCH(check_details) AGAINST('memory') GROUP BY package;
SELECT package,date_updated FROM histories WHERE MATCH(check_details) AGAINST('memory') GROUP BY package ORDER BY ;
SELECT package,date_updated FROM histories WHERE MATCH(check_details) AGAINST('memory') ORDER BY package;
