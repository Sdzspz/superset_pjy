DELIMITER ;;
CREATE DEFINER=`stat`@`%` PROCEDURE `xianjindai_cuishou_ribao1_7`(IN `start_time` datetime, IN `end_time` datetime, IN `param1` varchar(100))
BEGIN
	#Routine body goes here...

SELECT '姓名', '累计入催单数', '累计入催金额', '新入催单数', '新入催金额', '当日还款单数', '当日还款金额', '累计还款单数', '累计还款金额', 
	'总回收率（单数）', '总回收率（金额）', '新回收率(单数)', '新回收率(金额)';

SET @date := date(start_time); -- SET @date := date(now()); 
SET @start_time := concat(DATE_FORMAT(@date,'%Y-%m'), '-', '21 00:00:00');
IF @start_time > start_time THEN 
SET @start_time := SUBDATE(@start_time,INTERVAL 1 month);
END IF;
SET @end_time := concat(@date, ' 23:59:59');


IF param1 = '飞行贷' THEN
SET @type_min := 'D';
SET @type_max := 'P';
ELSEIF param1 = '信用飞' THEN
SET @type_min := 'A';
SET @type_max := 'B';
ELSE
SET @type_min := 'A';
SET @type_max := 'P';
END IF;


SELECT
t1.company_name as '姓名'
,t2.total_count as '累计入催单数'
,t3.total_amount as '累计入催金额'
,t2.new_count as '新入催单数'
,t2.new_amount as '新入催金额'
,t4.day_paid_count as '当日还款单数'
,t4.day_paid_amount as '当日还款金额'
,t5.total_paid_count as '累计还款单数'
,t5.total_paid_amount as '累计还款金额'
,concat(round(t5.total_paid_count/t2.total_count*100, 2), '%') as '总回收率（单数）'
,concat(round(t5.total_paid_amount/t3.total_amount*100, 2), '%') as '总回收率（金额）'
,concat(round(t6.new_paid_count/t2.new_count*100, 2), '%') as '新入催回收率（单数）'
,concat(round(t6.new_paid_amount/t2.new_amount*100, 2), '%') as '新入催回收率（金额）'

FROM 
(
SELECT 
DISTINCT company_name 
FROM shoufuyou_v2.CashPushRepayDivision
WHERE company_name NOT LIKE '委外%'
) t1
LEFT JOIN 
(
SELECT 
company_name 
,count(DISTINCT order_number) as total_count  -- 累计入催单数
,count((is_new = 1 AND left(cp.created_time, 10) = @date) or NULL) as new_count  -- 当日新入催单数
,sum(if(is_new = 1 AND left(cp.created_time, 10) = @date, overdue_amount, 0)) as new_amount  -- 当日入催金额
FROM shoufuyou_v2.CashPushRepayDivision cp
JOIN shoufuyou_v2.CashLoanOrder co USING(order_number)
WHERE cp.created_time BETWEEN @start_time AND @end_time
AND co.type >= @type_min AND co.type <= @type_max 
AND TO_DAYS('2017-12-05')-TO_DAYS(cp.created_time)+cp.overdue_days <2
AND cp.overdue_days < 8
GROUP BY company_name
) t2 using(company_name)
LEFT JOIN 

(

SELECT 
company_name
,sum(t1.amount) total_amount
FROM 
	(
		SELECT DISTINCT order_number, company_name, max(overdue_amount) amount 
		FROM shoufuyou_v2.CashPushRepayDivision cp 
		JOIN shoufuyou_v2.CashLoanOrder co USING(order_number)
		WHERE cp.created_time BETWEEN @start_time AND @end_time
		AND co.type >= @type_min AND co.type <= @type_max
		AND TO_DAYS('2017-12-05')-TO_DAYS(cp.created_time)+cp.overdue_days <2
		AND cp.overdue_days < 8
		GROUP BY company_name, order_number
	) t1 
GROUP BY company_name
) t3 using(company_name)

LEFT JOIN 
(
SELECT 
company_name
,count(DISTINCT cp.order_number) AS day_paid_count  -- 当日还款个数
,round(sum(cb.principal + cb.interest + cb.paid_platform_fee + cb.paid_after_loan_fee)/100, 2) as day_paid_amount -- 当日还款金额
FROM 
shoufuyou_v2.CashPushRepayDivision cp
JOIN shoufuyou_v2.CashBill cb USING(order_number)
WHERE date(cb.paid_time) = @date
AND date(cp.created_time) = @date
AND cb.paid_time > cb.payment_deadline
AND cb.loan_type >= @type_min AND cb.loan_type <= @type_max
AND TO_DAYS('2017-12-05')-TO_DAYS(cp.created_time)+cp.overdue_days <2
AND cp.overdue_days < 8
GROUP BY company_name
) t4 using(company_name)

LEFT JOIN 
(
SELECT 
company_name
,count(DISTINCT cb.order_number) AS total_paid_count  -- 累计还款个数
,round(sum(cb.principal + cb.interest + cb.paid_platform_fee + cb.paid_after_loan_fee)/100, 2) as total_paid_amount -- 累计还款金额
FROM 
shoufuyou_v2.CashPushRepayDivision cp
JOIN shoufuyou_v2.CashBill cb USING(order_number)
WHERE date(cb.paid_time) = date(cp.created_time)
AND date(cb.paid_time) BETWEEN @start_time AND @end_time
AND cb.paid_time > cb.payment_deadline
AND cb.loan_type >= @type_min AND cb.loan_type <= @type_max
AND TO_DAYS('2017-12-05')-TO_DAYS(cp.created_time)+cp.overdue_days <2
AND cp.overdue_days < 8
GROUP BY company_name
) t5 using(company_name)

LEFT JOIN 
(
SELECT 
company_name
,count(DISTINCT cp.order_number) AS new_paid_count  -- 当日新入催还款个数
,round(sum(cb.principal + cb.interest + cb.paid_platform_fee + cb.paid_after_loan_fee)/100, 2) as new_paid_amount -- 当日新入催还款金额
FROM 
shoufuyou_v2.CashPushRepayDivision cp
JOIN shoufuyou_v2.CashBill cb USING(order_number)
WHERE date(cb.paid_time) >= @date
AND date(cp.created_time) = @date
AND cb.paid_time > cb.payment_deadline
AND cb.loan_type >= @type_min AND cb.loan_type <= @type_max
AND is_new = 1 
GROUP BY company_name
) t6 using(company_name)

ORDER BY FIELD(t1.company_name,'蒋明华','陆陈聪','贷后帮','公如旺','茂源','鹏盛','豫龙');

END;;
DELIMITER ;