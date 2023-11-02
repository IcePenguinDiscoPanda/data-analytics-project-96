with
visitors_and_leads as (
    select
        s.visitor_id,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.status_id,
        date(s.visit_date) as visit_date,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc',
            'cpm',
            'cpa',
            'youtube',
            'cpp',
            'tg',
            'social'
        )
    order by s.visitor_id
),
last_visits_and_leads as (
    select * from visitors_and_leads
    where rn = 1
),
advertising_ya_vk as (
    select
        date(campaign_date) as advertising_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as advertising_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
),
final_query as (
select
    date(lvl.visit_date) as visit_date,
    count(lvl.visitor_id) as visitors_count,
    lvl.utm_source,
    lvl.utm_medium,
    lvl.utm_campaign,
    ayv.total_cost,
    count(lvl.visitor_id) filter (where lvl.lead_id is not null) as leads_count,
    count(lvl.visitor_id) filter (where lvl.status_id = 142) as purchases_count,
    sum(lvl.amount) filter (where lvl.status_id = 142) as revenue
from last_visits_and_leads as lvl
left join advertising_ya_vk as ayv
    on
        lvl.visit_date = ayv.advertising_date
        and lvl.utm_source = ayv.utm_source
        and lvl.utm_medium = ayv.utm_medium
        and lvl.utm_campaign = ayv.utm_campaign
group by 1, 3, 4, 5, 6
order by 9 desc nulls last, 1, 2 desc, 3, 4, 5
)

--ЗАПРОСЫ В ДАШБОРД

--select * from final_query
--количество пользователей
select sum(visitors_count) from final_query  
--количество лидов
select sum(leads_count) from final_query
--конверсия в лиды
select round(sum(leads_count)*100.0/sum(visitors_count), 2) from final_query
--конверсия в оплату
select round(sum(purchases_count)*100.0/sum(leads_count), 2) from final_query
--затраты на рекламу
select sum(total_cost) from final_query
--выручка
select sum(revenue) from final_query
--пользователи по неделям и месяцам
select  
	case 
		when visit_date between '2023-06-01' and '2023-06-04' then '01/06-04/06' 
		when visit_date between '2023-06-05' and '2023-06-11' then '05/06-11/06' 
		when visit_date between '2023-06-12' and '2023-06-18' then '12/06-18/06' 
		when visit_date between '2023-06-19' and '2023-06-25' then '19/06-25/06'  
		when visit_date between '2023-06-26' and '2023-06-30' then '26/06-30/06'
	end,
	utm_source,
	sum(visitors_count)
from final_query
group by 1, 2
--пользователи по дням
select 
	visit_date,
	case 
    	when utm_source like 'vk%' then 'vk'
    	when utm_source like '%andex%' then 'yandex'
    	when utm_source like 'twitter%' then 'twitter'
    	when utm_source like '%telegram%' then 'telegram'
    	when utm_source like 'facebook%' then 'facebook'
    	else utm_source end,
    sum(visitors_count)
    from final_query
    group by 1, 2	
    order by 1
--затраты на рекламу
select 
	visit_date,
	utm_source,
	sum(total_cost)
from final_query
where total_cost <> 0
group by 1, 2
order by 1
--CPU (CPL, CPPU и ROI меняется только агрегат, CPL - sum(total_cost) * 1.0/ sum(leads_count), CPPU - sum(total_cost) * 1.0/ sum(purchases_count), ROI - (sum(revenue) - sum(total_cost)) * 1.0/ sum(total_cost))
select round(sum(total_cost)*1.0/sum(visitors_count), 2) from final_query
--CPU source (то же самое с medium и campaign)
select 
	utm_source, 
	round(sum(total_cost)*1.0/sum(visitors_count), 2) as cpu_source 
from final_query 
group by 1 
having round(sum(total_cost)*1.0/sum(visitors_count), 2) is not null
 	