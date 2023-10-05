with prom as (
    select
        distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        'source' as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id
        and l.created_at >= s.visit_date 
where s.medium in (
    'cpc',
    'cpm',
    'cpa',
    'youtube',
    'cpp',
    'tg',
    'social'
)
)
select *
from prom
order by
amount desc nulls last,
visit_date asc,
utm_source asc,
utm_medium asc,
utm_campaign asc