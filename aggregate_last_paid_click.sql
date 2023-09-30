with prefinal_table as (
    select
        s.visitor_id,
        s.visit_date,
        date_trunc('day', s.visit_date) as visit_day,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content
    from sessions as s
    where s.campaign is not null
    order by 1
),
visits_per_day as (
    select
        date_trunc('day', s.visit_date) as visit_day,
        count(date_trunc('day', s.visit_date)) as visitors_count
    from sessions as s
    where campaign is not null
    group by 1
    order by 1
),
leads_per_day as (
    select
        date_trunc('day', l.created_at) as lead_day,
        count(date_trunc('day', l.created_at)) as leads_count,
        count(date_trunc('day', l.created_at)) filter (
            where closing_reason = 'Успешная продажа' or status_id = 142
        ) as purchases_count,
        sum(amount) filter (
            where closing_reason = 'Успешная продажа' or status_id = 142
        ) as revenue
    from leads as l
    group by 1
    order by 1
)
select
    pre.visit_date,
    pre.utm_source,
    pre.utm_medium,
    pre.utm_campaign,
    vst.visitors_count,
    case
        when pre.utm_source = 'vk' then vk.daily_spent
        when pre.utm_source = 'yandex' then ya.daily_spent
    end as total_cost,
    lds.leads_count,
    lds.purchases_count,
    lds.revenue
from prefinal_table as pre
left join visits_per_day as vst on pre.visit_day = vst.visit_day
left join leads_per_day as lds
on
    pre.visit_day = lds.lead_day
left join vk_ads as vk
on
    pre.utm_source = vk.utm_source
    and pre.utm_medium = vk.utm_medium
    and pre.utm_campaign = vk.utm_campaign
    and pre.utm_content = vk.utm_content
    and pre.visit_day = vk.campaign_date
left join ya_ads as ya
on
    pre.utm_source = ya.utm_source
    and pre.utm_medium = ya.utm_medium
    and pre.utm_campaign = ya.utm_campaign
    and pre.utm_content = ya.utm_content
    and pre.visit_day = ya.campaign_date
order by
lds.revenue desc,
pre.visit_date asc,
vst.visitors_count desc,
pre.utm_source asc,
pre.utm_medium asc,
pre.utm_campaign asc
limit 15