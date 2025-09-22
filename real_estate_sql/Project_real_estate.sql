
-- Определим аномальные значения (выбросы) по значению перцентилей:
/*WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);*/




-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits))
        AND (balcony < (SELECT balcony_limit FROM limits))
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)))
    )
, categories AS
-- Разделим на категории по региону и сегменту
(SELECT  f.id,
		COUNT (f.id) OVER () AS total_count,
		CASE WHEN c.city='Санкт-Петербург'
			THEN 'Санкт-Петербург'
			ELSE 'ЛенОбл'
		END AS region,
		CASE WHEN a.days_exposition<=30
			THEN 'до 1 месяца'
			WHEN a.days_exposition>30 AND a.days_exposition<=90
			THEN 'до 3 месяцев'
			WHEN a.days_exposition>90 AND a.days_exposition<=180
			THEN 'до 6 месяцев'
			WHEN a.days_exposition>180
			THEN 'свыше 6 месяцев'
		END AS active_period,
		t.TYPE AS settlement,
		f.total_area,
		a.last_price/f.total_area AS price_per_meter,
		f.rooms,
		f.balcony,
		f.floor,
		f.floors_total 
FROM real_estate.flats f
JOIN real_estate.advertisement a using (id)
JOIN real_estate.city c using (city_id)
JOIN real_estate.TYPE t ON f.type_id=t.type_id
WHERE id IN (SELECT * FROM filtered_id) 
	AND t.TYPE='город' 
	AND a.days_exposition IS NOT NULL)
--Рассчет метрик в каждом сегменте активности в разрезе региона
SELECT categories.region,--Регион
		categories.active_period,--Сегмент активности
		count(DISTINCT categories.id) AS adv_count, -- Количество объявлений в каждом сегменте
		SUM(count(DISTINCT categories.id)) OVER (PARTITION BY categories.region) AS total_region,--Всего объявлений в регионе по всем сегментам активности
		(100*count(DISTINCT categories.id)::numeric(10,2)/SUM(count(DISTINCT categories.id)) OVER (PARTITION BY categories.region))::numeric(10,0) AS adv_share,--Доля объявлений
		AVG(categories.price_per_meter)::numeric(10,2) AS avg_price_sqm, --Средняя стоимость 1 кв.м. недвижимости
		avg(categories.total_area)::numeric(10,2) AS avg_area, -- Средняя площадь недвижимости
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY categories.rooms) AS median_rooms, --Медиана кол-ва комнат
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY categories.balcony) AS median_balcony, -- Медиана кол-ва балконов
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY categories.floor) AS median_floor, -- Медиана этажа квартиры
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY categories.floors_total) AS median_total_floor --Медиана этажности здания
FROM real_estate.flats f
JOIN categories USING (id)
WHERE id IN (SELECT * FROM filtered_id) 
AND categories.active_period IS NOT NULL 
GROUP BY categories.region, categories.active_period, categories.total_count
ORDER BY categories.region DESC,  categories.active_period;




--Таблица 2.1 Сезонные различия активности в публикации объявлений о продаже недвижимости
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits))
        AND (balcony < (SELECT balcony_limit FROM limits))
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)))
    )
-- Выведем объявления без выбросов:
SELECT CASE 
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 1
			THEN 'январь'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 2
			THEN 'февраль'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 3
			THEN 'март'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 4
			THEN 'апрель'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 5
			THEN 'май'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 6
			THEN 'июнь'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 7
			THEN 'июль'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 8
			THEN 'август'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 9
			THEN 'сентябрь'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 10
			THEN 'октябрь'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 11
			THEN 'ноябрь'
			WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 12
			THEN 'декабрь'
		END AS month_publication, --Месяц публикации объявления
		ROW_NUMBER () OVER (ORDER BY COUNT(f.id) DESC) AS RANK, -- Ранг по количеству объявлений
		COUNT(f.id) AS advert_count, --Количество объявлений в этом месяце
		--SUM (COUNT(f.id)) OVER () AS sum_adv_count, --Всего объявлений 
		(100*(COUNT(f.id)/SUM (COUNT(f.id)) OVER ()))::numeric(10,0) AS adv_share, --Доля объявлений в этом месяце от общего количества
		AVG(a.last_price/f.total_area)::numeric(10,2) AS avg_price_per_sqm, --Средняя стоимость 1 кв.м. недвижимости
		AVG(f.total_area)::numeric(10,2) AS avg_area -- Средняя площадь недвижимости
FROM real_estate.flats f
JOIN real_estate.advertisement a using(id)
JOIN real_estate.TYPE t ON f.type_id=t.type_id
WHERE id IN (SELECT * FROM filtered_id) 
	AND t.TYPE='город'
	AND EXTRACT(MONTH FROM a.first_day_exposition) IS NOT NULL 
	AND EXTRACT(YEAR FROM a.first_day_exposition) IN (2015,2016,2017,2018) --Использованы данные только за полные года
GROUP BY month_publication;
 
	
--Таблица 2.2 Сезонные различия активности в снятии объявлений с продажи
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits))
        AND (balcony < (SELECT balcony_limit FROM limits))
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)))
    )
-- Выведем объявления без выбросов:
SELECT 
		CASE 
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 1
			THEN 'январь'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 2
			THEN 'февраль'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 3
			THEN 'март'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 4
			THEN 'апрель'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 5
			THEN 'май'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 6
			THEN 'июнь'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 7
			THEN 'июль'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 8
			THEN 'август'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 9
			THEN 'сентябрь'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 10
			THEN 'октябрь'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 11
			THEN 'ноябрь'
			WHEN EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) = 12
			THEN 'декабрь'
		END AS month_sold, --Месяц снятия с продажи
		ROW_NUMBER () OVER (ORDER BY COUNT(f.id) DESC), --Ранг
		COUNT(f.id) AS advert_count, --Количество объявлений
		--SUM (COUNT(f.id)) OVER () AS sum_adv_count, --Всего объявлений 
		(100*(COUNT(f.id)/SUM (COUNT(f.id)) OVER ()))::numeric(10,0) AS adv_share, --Доля объявлений в этом месяце от общего количества
		AVG(a.last_price/f.total_area)::numeric(10,2) AS avg_price_per_sqm, --Средняя стоимость 1 кв.м. недвижимости
		AVG(f.total_area)::numeric(10,2) AS avg_area --Средняя площадь недвижимости
FROM real_estate.flats f
JOIN real_estate.advertisement a using(id) 
JOIN real_estate.TYPE t ON f.type_id=t.type_id
WHERE id IN (SELECT * FROM filtered_id) 
	AND t.TYPE='город'
	AND EXTRACT(MONTH FROM a.first_day_exposition) IS NOT NULL 
	AND EXTRACT(YEAR FROM a.first_day_exposition) IN (2015,2016,2017,2018) --Использованы данные только за полные года
	AND EXTRACT(MONTH FROM (DATE(a.first_day_exposition) + cast(a.days_exposition AS int))) IS NOT NULL 
GROUP BY month_sold;




-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits))
        AND (balcony < (SELECT balcony_limit FROM limits))
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)))
    ),
cte AS (SELECT
	c.city,
	COUNT (DISTINCT f.id) AS total_count, --Общее количество объявлений
	COUNT(DISTINCT f.id) FILTER (WHERE a.days_exposition IS NOT NULL) AS sold_count,--Количество снятых с продажи объявлений
	(100*COUNT(DISTINCT f.id) FILTER(WHERE a.days_exposition IS NOT null)::numeric(10,2)/COUNT (f.id))::numeric(10,2) AS sold_share, --Доля проданных объектов
	AVG(a.last_price/f.total_area)::numeric(10,2) AS avg_price_sqm,
	AVG(f.total_area)::numeric(10,2) AS avg_area, --Средняя площадь недвижимости
	AVG(a.days_exposition)::numeric(10,0) AS days_exposition
FROM real_estate.flats f
JOIN real_estate.advertisement a ON f.id=a.id
JOIN real_estate.city c ON f.city_id=c.city_id	
WHERE f.id IN (SELECT * FROM filtered_id) 
	AND c.city != 'Санкт-Петербург'
GROUP BY c.city
ORDER BY (100*COUNT(f.id) FILTER(WHERE a.days_exposition IS NOT null)::numeric(10,2)/COUNT (f.id))::numeric(10,2) DESC, COUNT (f.id) DESC)
SELECT cte.city,
	ROW_NUMBER () OVER (ORDER BY cte.total_count DESC) AS rank,
	cte.total_count,
	cte.sold_share,
	cte.avg_price_sqm,
	cte.avg_area,
	(cte.days_exposition)::numeric(10,2)
FROM cte 
ORDER BY cte.total_count DESC, cte.sold_share DESC 
LIMIT 15





