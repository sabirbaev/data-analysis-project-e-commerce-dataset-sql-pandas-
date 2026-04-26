-- ====================================================
-- Блок 1 — Очистка и подготовка (создание VIEW заново)
-- ====================================================
CREATE VIEW clean_data AS 
SELECT 
    "InvoiceNo", 
    "StockCode", 
    "Description", 
    "Quantity", 
    "InvoiceDate", 
    "UnitPrice", 
    "CustomerID", 
    "Country", 
    "Quantity" * "UnitPrice" AS revenue,
    TO_CHAR(TO_TIMESTAMP("InvoiceDate", 'MM/DD/YYYY HH24:MI'), 'YYYY-MM') AS month,
    TO_CHAR(TO_TIMESTAMP("InvoiceDate", 'MM/DD/YYYY HH24:MI'), 'YYYY-MM-DD') AS day
FROM data
WHERE "Quantity" > 0 AND "UnitPrice" > 0;

-- ====================================================
-- Блок 2 — Базовые метрики
-- ====================================================

-- 2.1 Общая выручка
SELECT ROUND(SUM(revenue)::numeric, 2) AS total_revenue
FROM clean_data;

-- 2.2 Количество заказов (уникальных InvoiceNo)
SELECT COUNT(DISTINCT "InvoiceNo") AS total_orders
FROM clean_data;

-- 2.3 Количество клиентов (уникальных CustomerID)
SELECT COUNT(DISTINCT "CustomerID") AS total_customers
FROM clean_data;

--2.4 Средний чек(округленный до 2 цифр, после запятой)
select ROUND(AVG(revenue)::numeric, 2) as AOV
from clean_data cd;

-- ====================================================
-- Блок 3 — Временной анализ
-- ====================================================

--3.1 Выручка: по дням
select day, ROUND(SUM(revenue)::numeric, 2) as revenue_by_day
from clean_data cd 
group by day
order by day;

--3.2 Выручка: по месяцам
select month, ROUND(SUM(revenue)::numeric, 2) as revenue_by_month
from clean_data cd 
group by month
order by month;

--3.3 Количество заказов: по дням
select day, COUNT(distinct "InvoiceNo") as daily_orders_count
from clean_data cd 
group by day
order by day;

--3.3 Количество заказов: по месяцам
select month, COUNT(distinct "InvoiceNo") as monthly_orders_count
from clean_data cd 
group by month
order by month;

--3.4 день с максимальной выручкой
select day, ROUND(SUM(revenue)::numeric, 2) as max_revenue_by_day
from clean_data cd 
group by day
order by max_revenue_by_day desc
limit 1;

--3.5 месяц с максимальной выручкой
select month, ROUND(SUM(revenue)::numeric, 2) as max_revenue_by_month
from clean_data cd 
group by month
order by max_revenue_by_month desc
limit 1;

-- ====================================================
-- Блок 4 — Анализ товаров
-- ====================================================

-- 4.1 топ 5 товаров по выручке
select cd."Description"  , round(sum(cd.revenue )::numeric, 2) total_revenue
from clean_data cd 
group by "Description" 
order by total_revenue DESC
limit 5;

-- 4.2 топ 5 товаров по кол-ву
select cd."Description"  , SUM(cd."Quantity" ) total_count
from clean_data cd 
group by "Description" 
order by total_count DESC
limit 5;

--4.3 товары с минимальными продажами
select cd."Description"  , SUM(cd."Quantity" ) total_count
from clean_data cd 
group by "Description" 
order by total_count 
limit 5;


--4.4 проверить существует ли "перекос" (несколько товаров дают большую часть выручки)
with top_5_list as (
	select cd."Description"  , round(sum(cd.revenue )::numeric, 2) total_revenue
	from clean_data cd 
	group by "Description" 
	order by total_revenue DESC
	limit 5),
total_revenue_top5 as (select sum(total_revenue) as total_summ_top5 from top_5_list),
total_revenue as (select sum(revenue) as total_sum from clean_data)

select (total_summ_top5::numeric/total_sum)*100 as ratio
from total_revenue_top5, total_revenue; --сумма выручки топ 5 товаров занимает 7% от общей выручки 


-- ====================================================
-- Блок 5 — Анализ клиентов
-- ====================================================

-- 5.1 Для каждого клиента: количество заказов
select "CustomerID", count(distinct "InvoiceNo") 
from clean_data cd 
where cd."CustomerID" is not NULL
group by "CustomerID"
order by count desc;

-- 5.2 Для каждого клиента: общая выручка
select "CustomerID", round(sum(revenue)::numeric,2 ) as total_revenue
from clean_data cd 
where cd."CustomerID" is not NULL
group by "CustomerID"
order by total_revenue desc;

--5.3 Объединить: заказы + выручка
select "CustomerID", COUNT(distinct cd."InvoiceNo"), round(sum(revenue)::numeric,2 ) as total_revenue
from clean_data cd 
where cd."Description" is not null and "CustomerID" is not null
group by "CustomerID"
order by total_revenue desc;

-- 5.4 Найти: топ-5 клиентов по выручке
select "CustomerID", round(sum(revenue)::numeric,2 ) as total_revenue
from clean_data cd 
where cd."CustomerID" is not NULL
group by "CustomerID"
order by total_revenue desc
limit 5;

-- 5.5 Найти: сколько клиентов сделали только 1 заказ
with get_data as(select "CustomerID", count(distinct "InvoiceNo") 
from clean_data cd 
where cd."CustomerID" is not null
group by "CustomerID"
having count(distinct "InvoiceNo") = 1
order by count desc)

select count("CustomerID")
from get_data;

-- 5.6 Найти: среднее количество заказов на клиента
with get_data as (select "CustomerID", count(distinct "InvoiceNo") 
from clean_data cd 
where cd."CustomerID" is not NULL
group by "CustomerID")

select round(avg(count))
from get_data;


-- ====================================================
-- Блок 6 
-- ====================================================

-- 6.1 Найти: дату последней покупки каждого клиента
select "CustomerID", MAX(day)
from clean_data cd 
where cd."CustomerID" is not null
group by "CustomerID"; 

-- 6.2 Посчитать: сколько дней клиент “живёт” (между первой и последней покупкой)
select "CustomerID", min(day), MAX(day), MAX(day::date) - MIN(day::date) as days
from clean_data cd 
where cd."CustomerID" is not null
group by "CustomerID" 

-- 6.3 Сделать: простую сегментацию клиентов: 1 заказ → new 2–3 → returning 4+ → loyal
select "CustomerID", count(distinct "InvoiceNo"),
case when count(distinct "InvoiceNo") = 1 then 'new' 
	 when count(distinct "InvoiceNo") between 2 and 3 then 'returning'
	 when count(distinct "InvoiceNo") >= 4 then 'loyal' else 'unknown status' end as status 
from clean_data cd 
group by cd."CustomerID"; 

-- 6.4 Найти: клиента с максимальным количеством заказов
select "CustomerID", count(distinct "InvoiceNo") 
from clean_data cd 
where cd."CustomerID" is not NULL
group by "CustomerID"
order by count desc
limit 1;

-- 6.5 Найти: последний заказ каждого клиента (через оконную функцию)
with get_data as (select cd."CustomerID" , cd."InvoiceNo" , "InvoiceDate",
row_number() OVER(partition by cd."CustomerID" order by cd."InvoiceDate" desc) as row_num
from clean_data cd)

select *
from get_data
where row_num = 1;

-- 6.6 Сделать: ранжирование клиентов по выручке (RANK / DENSE_RANK)
with get_data as(select cd."CustomerID" , sum(revenue) as total_revenue 
from clean_data cd 
where cd."CustomerID"  is not null
group by cd."CustomerID" )

select *,
dense_rank() over(order by total_revenue desc) as ranking
from get_data


-- ====================================================
-- Блок 7 
-- ====================================================

-- 7.1 Посчитать: накопительную выручку по дням (running total)
with get_data as(
select cd.day, sum(revenue) as total_revenur_by_day
from clean_data cd 
group by day

)
select day, 
SUM(round(total_revenur_by_day::numeric, 2)) over(order by day) as running_total
from get_data
order by day;


-- 7.2 Посчитать: скользящую выручку за 7 дней
select cd.day, round(sum(revenue) over (order by day rows between 6 preceding and current row)::numeric,2 ) as total_revenue_by_day
from clean_data cd;


-- 7.3 Найти: клиентов, у которых выручка выше среднего
with customer_revenue as (select cd."CustomerID" , 
sum(cd.revenue) as total_revenue
from clean_data cd
group by cd."CustomerID"),
average_revenue_total as(select avg(total_revenue) as average_revenue
from customer_revenue  )

select *
from customer_revenue cr
cross join average_revenue_total av
where cr.total_revenue > av.average_revenue;



