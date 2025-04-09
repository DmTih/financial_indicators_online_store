/*
Проект: Финансовые показатели интернет-магазина.

Цель: Исследование направлено на понимание источников дохода, динамики монетизации и 
      прибыльности бизнеса для принятия управленческих решений.

Дано:
- оплата за заказ поступает сразу после его оформления
- платящие пользователи - пользователи, которые оформили хотя бы один заказ
- в августе постоянные затраты составляли 120 000 рублей в день, в сентябре — 150 000 рублей
- в августе комплектация одного заказа обходилась в 140 рублей, в сентябре — 115 рублей
- в августе и сентябре оплата за доставку заказа курьером составляла 150 рублей
- в августе бонус для курьеров, доставивших не менее 5 заказов в день, составлял 400 рублей, в сентябре — 500 рублей  
- выплата курьерам за доставленный заказ начисляется сразу после его доставки
- на некоторые группы товаров (список) НДС составляет 10%, на остальные — 20%

Описание используемых датасетов:
1. user_actions (действия пользователей)
- user_id - уникальный идентификатор пользователя
- order_id - идентификатор заказа
- action - тип действия: 'create_order' (создание заказа) или 'cancel_order' (отмена заказа)
- time - временная метка совершения действия

2. orders (информация о заказах)
- order_id - уникальный идентификатор заказа
- creation_time - дата и время создания заказа
- product_ids - массив идентификаторов товаров в заказе

3. products (информация о товарах)
- product_id - уникальный идентификатор товара
- name - наименование товара
- price - цена товара в рублях

Что делал: 
1. Рассчитал дневную выручку, суммарную выручку на день, прирост выручки относительно предыдущего дня
2. Рассчитал ARPU, ARPPU, AOV по дням
3. Рассчитал ARPU, ARPPU, AOV по неделям
4. Рассчитал Running ARPU, Running ARPPU, Running AOV чтобы видеть общую динамику  
5. Рассчитал ежедневную выручку с заказов новых пользователей, посчитал их долю в общей выручке
6. Рассчитал суммарную выручку по товарам и долю выручки от продажи товара в общей выручке полученной за весь период
7. Рассчитал валовую прибыль учитывая постоянные и переменные затраты и НДС, а также долю валовой прибыли в дневной выручке.
8. Собрал графики в дашборд, сделал выводы. 
*/


--Шаг 1. Считаю дневную выручку, суммарную выручку на день, прирост выручки относительно предыдущего дня.

SELECT
    date,
    revenue,
    SUM(revenue) OVER (ORDER BY date) AS total_revenue,
    ROUND((revenue - LAG(revenue, 1) OVER (ORDER BY date))/ LAG(revenue, 1) OVER (ORDER BY date) * 100, 2) AS revenue_change
FROM (
    SELECT 
        date,
        SUM(price) AS revenue
    FROM (
        SELECT 
            creation_time::DATE AS date,
            unnest(product_ids) AS product_id
        FROM orders
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        ) sub_1
    LEFT JOIN products USING (product_id)
    GROUP BY date
    ) sub_2
ORDER BY date

--Шаг 2. Рассчитал среднюю выручку на одного пользователя (ARPU), выручку на одного платящего пользователя (ARPPU), средний чек (AOV) по дням.

WITH
cancel_orders AS (
    SELECT order_id 
    FROM user_actions 
    WHERE action = 'cancel_order'
    )

SELECT 
    uu.date,
    ROUND(r.revenue / uu.unique_users, 2)  AS arpu,
    ROUND(r.revenue / pu.paying_users, 2) AS arppu,
    ROUND(r.revenue /  pu.number_of_orders, 2) AS aov
FROM (
    SELECT 
        time::DATE AS date,
        COUNT(DISTINCT user_id) AS unique_users
    FROM user_actions
    GROUP BY date
    ) uu
LEFT JOIN (
    SELECT
        o.creation_time::DATE AS date,
        COUNT(o.order_id) AS number_of_orders,
        COUNT(DISTINCT user_id) AS paying_users 
    FROM orders o
    JOIN user_actions u USING (order_id)
    WHERE order_id NOT IN (SELECT * FROM cancel_orders)
    GROUP BY date
    ) pu
USING (date)
LEFT JOIN (
    SELECT 
        date,
        SUM(price) AS revenue
    FROM (
        SELECT 
            creation_time::DATE AS date,
            unnest(product_ids) AS product_id
        FROM orders
        WHERE order_id NOT IN (SELECT * FROM cancel_orders)
        ) sub_1
    LEFT JOIN products USING (product_id)
    GROUP BY date
    ) r
USING (date)
ORDER BY date

--Шаг 3. Рассчитал ARPU, ARPPU, AOV по неделям.

SELECT 
    uu.weekday,
    CASE --нормализую наименования дней недели перед проверкой в выражении CASE
        WHEN LOWER(TRIM(uu.weekday)) = 'monday' THEN 1
        WHEN LOWER(TRIM(uu.weekday)) = 'tuesday' THEN 2
        WHEN LOWER(TRIM(uu.weekday)) = 'wednesday' THEN 3
        WHEN LOWER(TRIM(uu.weekday)) = 'thursday' THEN 4
        WHEN LOWER(TRIM(uu.weekday)) = 'friday' THEN 5
        WHEN LOWER(TRIM(uu.weekday)) = 'saturday' THEN 6
        WHEN LOWER(TRIM(uu.weekday)) = 'sunday' THEN 7
    END AS weekday_number,
    ROUND(r.revenue / uu.unique_users, 2)  AS arpu,
    ROUND(r.revenue / pu.paying_users, 2) AS arppu,
    ROUND(r.revenue /  pu.number_of_orders, 2) AS aov
FROM (
    SELECT 
        to_char(time::DATE, 'Day') AS weekday,
        COUNT(DISTINCT user_id) AS unique_users
    FROM user_actions
    WHERE time::DATE >= '2022-08-26'
    GROUP BY weekday
    ) uu
LEFT JOIN (
    SELECT
        to_char(o.creation_time::DATE, 'Day') AS weekday,
        COUNT(o.order_id) AS number_of_orders,
        COUNT(DISTINCT user_id) AS paying_users 
    FROM orders o
    JOIN user_actions u USING (order_id)
    WHERE order_id NOT IN (SELECT order_id 
                           FROM user_actions 
                           WHERE action = 'cancel_order')
        AND o.creation_time::DATE >= '2022-08-26'
    GROUP BY weekday
    ) pu
USING (weekday)
LEFT JOIN (
    SELECT 
        weekday,
        SUM(price) AS revenue
    FROM (
        SELECT 
            to_char(creation_time::DATE, 'Day') AS weekday,
            unnest(product_ids) AS product_id
        FROM orders
        WHERE order_id NOT IN (SELECT order_id 
                               FROM user_actions 
                               WHERE action = 'cancel_order')
            AND creation_time::DATE >= '2022-08-26'
        ) sub_1
    LEFT JOIN products USING (product_id)
    GROUP BY weekday
    ) r
USING (weekday)
ORDER BY weekday_number

--Шаг 4. Рассчитал Running ARPU, Running ARPPU, Running AOV.

WITH
cancel_orders AS (
    SELECT order_id 
    FROM user_actions 
    WHERE action = 'cancel_order'
    ),
first_activity AS (
    SELECT 
        user_id,
        MIN(time::DATE) AS min_date
    FROM user_actions
    GROUP BY user_id
    ),
unique_users AS (
    SELECT
        min_date AS date,
        COUNT(DISTINCT user_id) AS unique_users
    FROM first_activity
    GROUP BY min_date
    ),
first_activity_paying_users AS (
    SELECT 
       user_id,
       MIN(time::DATE) AS min_date
    FROM user_actions
    WHERE order_id NOT IN (SELECT * FROM cancel_orders)
    GROUP BY user_id
    ),
paying_users AS (
    SELECT
        min_date AS date,
        COUNT(DISTINCT user_id) AS paying_users
    FROM first_activity_paying_users
    GROUP BY date
    ),
number_of_orders AS (
    SELECT
        creation_time::DATE AS date,
        COUNT(DISTINCT order_id) AS number_of_orders
    FROM orders
    WHERE order_id NOT IN (SELECT * FROM cancel_orders)
    GROUP BY date
    ),
revenue AS (
    SELECT 
        date,
        SUM(price) AS revenue
    FROM (
        SELECT 
            creation_time::DATE AS date,
            unnest(product_ids) AS product_id
        FROM orders
        WHERE order_id NOT IN (SELECT * FROM cancel_orders)
        ) sub_1
    LEFT JOIN products USING (product_id)
    GROUP BY date
    )

SELECT
    date,
    ROUND(running_revenue / running_unique_users, 2)  AS running_arpu,
    ROUND(running_revenue / running_paying_users, 2) AS running_arppu,
    ROUND(running_revenue / running_number_of_orders, 2) AS running_aov
FROM (
    SELECT
        date,
        SUM(unique_users) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_unique_users,
        SUM(paying_users) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_paying_users,
        SUM(number_of_orders) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_number_of_orders,
        SUM(revenue) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue
    FROM (
        SELECT 
            uu.date,
            uu.unique_users,
            pu.paying_users,
            noo.number_of_orders,
            r.revenue
        FROM unique_users uu
        LEFT JOIN paying_users pu USING (date)
        LEFT JOIN revenue r USING (date)
        LEFT JOIN number_of_orders noo USING (date)
        ) AS indicators
    ) AS running_indicators
ORDER BY date


--Шаг 5. Рассчитал ежедневную выручку с заказов новых пользователей и её долю в общей выручке (включая старых пользователей).

--для каждого пользователя дата его первого действия в сервисе (вкл. отмененные заказов)
WITH
sub_first_action AS (
    SELECT 
        user_id,
        MIN(time::DATE) AS date_first_action
    FROM user_actions
    GROUP BY user_id
    ),
    
--стоимость каждого заказа в таблице orders
sub_order_value AS (
    SELECT
        order_id,
        SUM(price) AS order_value
    FROM
    (SELECT 
        order_id,
        unnest(product_ids) AS product_id
    FROM orders) t1
    LEFT JOIN products USING (product_id)
    GROUP BY order_id
    ),

-- выручка с каждого пользователя в его первый день
-- объединяю данные о стоимости заказов (sub_order_value) с user_actions чтобы узнать user_id, 
-- затем с датами начала использования приложения (sub_first_action)


sub_first_day_revenue AS (
    SELECT
        t2.user_id,
        fa.date_first_action,
        t2.revenue_per_day
    FROM (
        SELECT
            ua.user_id,
            ua.time::DATE AS date,
            SUM(ov.order_value) AS revenue_per_day
        FROM user_actions ua
        JOIN sub_order_value ov USING (order_id)
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        GROUP BY ua.user_id, date) t2
        JOIN sub_first_action fa ON t2.user_id = fa.user_id AND t2.date = fa.date_first_action
        
    ),  

-- выручка с заказов новых пользователей 
sub_new_users_revenue AS (
    SELECT
        date_first_action AS date,
        SUM(revenue_per_day) AS new_users_revenue
    FROM sub_first_day_revenue
    GROUP BY date
    ),

-- выручка с заказов всех пользователей 
sub_revenue AS (
    SELECT 
        date,
        SUM(price) AS revenue
    FROM (
        SELECT 
            creation_time::DATE AS date,
            unnest(product_ids) AS product_id
        FROM orders
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        ) t3
    LEFT JOIN products USING (product_id)
    GROUP BY date
    )

SELECT
date,
revenue,
new_users_revenue,
ROUND(new_users_revenue / revenue * 100, 2) AS new_users_revenue_share,
ROUND((revenue - new_users_revenue) / revenue * 100, 2) AS old_users_revenue_share
FROM (
    SELECT
        r.date,
        r.revenue,
        nr.new_users_revenue
    FROM sub_revenue r
    LEFT JOIN sub_new_users_revenue nr USING (date)
    ) t4
ORDER BY date

--Шаг 6. Рассчитал суммарную выручку по товарам, долю выручки от каждого товара в общей выручке за период.

WITH
sub_product_revenue AS (
    SELECT 
        p.name AS product_name,
        p.price * t1.orders_count AS revenue
    FROM products p
    LEFT JOIN (
        SELECT 
            unnest(product_ids) AS product_id,
            COUNT(order_id) AS orders_count
        FROM orders
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        GROUP BY product_id ) t1
    USING (product_id)
    ),

revenue_with_share AS (
    SELECT
        product_name,
        revenue,
        ROUND(revenue::decimal / SUM(revenue) OVER() * 100, 2) AS share_in_revenue
    FROM sub_product_revenue
    ),   

product_name_with_other AS (    
    SELECT
        CASE
            WHEN share_in_revenue < 0.5 THEN 'ДРУГОЕ'
            ELSE product_name
        END AS product_name,
        revenue,
        share_in_revenue
    FROM revenue_with_share
    )

SELECT
    product_name,
    SUM(revenue) AS revenue,
    SUM(share_in_revenue) AS share_in_revenue
FROM product_name_with_other
GROUP BY product_name
ORDER BY revenue DESC

--Шаг 7. Рассчитал валовую прибыль (учитывая постоянные и переменные затраты, а также НДС), долю валовой прибыли в дневной выручке.

WITH
sub_vat_percentage AS (
    SELECT
        t3.creation_time,
        p.name,
        p.price,
        CASE 
            WHEN name IN (
                'сахар', 'сухарики', 'сушки', 'семечки', 
                'масло льняное', 'виноград', 'масло оливковое', 
                'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 
                'овсянка', 'макароны', 'баранина', 'апельсины', 
                'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 
                'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 
                'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 
                'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 
                'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 'вафли', 'мандарины'
            ) THEN 10
            ELSE 20
        END AS vat_percentage
    FROM (
        SELECT
        creation_time,
        unnest(product_ids) AS product_id
        FROM orders o
        WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
        ) t3
    LEFT JOIN products p USING (product_id)
    ),
sub_revenue_and_tax AS (
    SELECT
        creation_time::DATE AS date,
        SUM(price) AS revenue,
        SUM(goods_tax) AS tax
    FROM (
        SELECT
            creation_time,
            price,
            ROUND((price * vat_percentage) / (100 + vat_percentage), 2) AS goods_tax
        FROM sub_vat_percentage
        ) t1
    GROUP BY date
    ),
sub_fc_costs AS (
    SELECT 
        time::DATE AS date,
        CASE
            WHEN DATE_PART('month', time) = 8 THEN 120000
            WHEN DATE_PART('month', time) = 9 THEN 150000
        END AS fc_costs
    FROM courier_actions
    GROUP BY date, DATE_PART('month', time)
    ),
sub_vc_delivered_order_costs AS ( 
    SELECT 
        time::DATE AS date,
        COUNT(order_id) * 150 AS vc_delivered_order_costs
    FROM courier_actions
    WHERE action = 'deliver_order' 
    GROUP BY date
    ),
sub_vc_assembly_costs AS ( 
    SELECT 
        time::DATE AS date,
        CASE
            WHEN DATE_PART('month', time) = 8 THEN 140
            WHEN DATE_PART('month', time) = 9 THEN 115
        END * COUNT(order_id) AS vc_assembly_costs
    FROM courier_actions
    WHERE action = 'accept_order' 
        AND order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
    GROUP BY date, DATE_PART('month', time)
    ),
sub_vc_bonus_costs AS (
    SELECT
        date,
        CASE
            WHEN DATE_PART('month', date) = 8 THEN 400
            WHEN DATE_PART('month', date) = 9 THEN 500
            END * COUNT(courier_id) AS vc_bonus_costs
    FROM (
        SELECT 
            time::DATE AS date,
            courier_id,
            COUNT(order_id) AS orders_count
        FROM courier_actions
        WHERE action = 'deliver_order' 
        GROUP BY date, courier_id
        HAVING COUNT(order_id) >=5
        ) t2
    GROUP BY date, DATE_PART('month', date)
    ),
sub_costs AS (
    SELECT
        date,
        (COALESCE(fc.fc_costs, 0) + 
        COALESCE(vcd.vc_delivered_order_costs, 0) + 
        COALESCE(vca.vc_assembly_costs, 0) + 
        COALESCE(vcb.vc_bonus_costs, 0))::DECIMAL AS costs
    FROM sub_fc_costs fc
    LEFT JOIN sub_vc_delivered_order_costs vcd USING(date)
    LEFT JOIN sub_vc_assembly_costs vca USING(date)
    LEFT JOIN sub_vc_bonus_costs vcb USING(date)
    )
SELECT
    rt.date,
    rt.revenue, --TR 
    c.costs, --TC=FC+VC 
    rt.tax, --НДС 
    rt.revenue - c.costs - rt.tax AS gross_profit, --ВП 
    SUM(rt.revenue) OVER(ORDER BY rt.date) AS total_revenue, --Суммарная выручка на текущий день 
    SUM(c.costs) OVER(ORDER BY rt.date) AS total_costs, --Суммарные затраты на текущий день 
    SUM(rt.tax) OVER(ORDER BY rt.date) AS total_tax, --Суммарный НДС на текущий день 
    SUM(rt.revenue - c.costs - rt.tax) OVER(ORDER BY rt.date) AS total_gross_profit, --Суммарную ВП на текущий день 
    ROUND((rt.revenue - c.costs - rt.tax) * 100 / rt.revenue, 2) AS gross_profit_ratio, --Доля ВП в выручке за этот день 
    ROUND(SUM(rt.revenue - c.costs - rt.tax) OVER(ORDER BY rt.date) * 100 / SUM(rt.revenue) OVER(ORDER BY rt.date), 2) AS total_gross_profit_ratio --Доля суммарной ВП в суммарной выручке на текущий день
FROM sub_revenue_and_tax rt
LEFT JOIN sub_costs c USING (date)
ORDER BY date

/*
Дашборд доступен по ссылке: https://redash.public.karpov.courses/public/dashboards/1y0yRyw24C1GOdtfrAsSoT2VSH5GdL3EPS3Eg9fx?org_slug=default


Выводы:
1. Динамика ежедневной выручки неоднородная, наблюдаются провалы (например, 6 сентября), связанные с снижением числа заказов.
2. Метрики ARPU и ARPPU коррелируют, но имеют значительный разброс. Это объясняется поведением пользователей: более активными заказами в выходные дни. 
3. Накопленная выручка на пользователя растёт при стабильном среднем чеке. Это указывает на увеличение числа заказов на пользователя — положительный тренд.
4. Выручка от новых пользователей остаётся высокой даже спустя две недели после запуска (~40%).
5. Мясная продукция — лидер по доле в выручке.
6. Сервис вышел на положительную валовую прибыль: ежедневная прибыль стала положительной с 31 августа, суммарная валовая прибыль — 5 сентября. Возможная причина: оптимизация стоимости сборки заказа в сентябре.
*/  