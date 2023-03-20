SET SEARCH_PATH = dannys_diner

-- 1. What is the total amount each customer spent at the restaurant?
SELECT a.customer_id, SUM(b.price) AS total_spent
FROM sales a
JOIN menu b 
ON A.product_id = b.product_id
GROUP BY a.customer_id
ORDER BY a.customer_id;
	
-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT(order_date)) AS total_visits
FROM sales
GROUP BY customer_id
ORDER BY customer_id;
	
-- 3. What was the first item from the menu purchased by each customer?
--Solution 1: Gets complete order for each customer on their first visit (Ex: Ordered a curry and sushi)
	--Since order_date is not time stamped, we don't actually know which item came first.
SELECT customer_id, product_name
FROM(
	SELECT a.customer_id, a.order_date, b.product_name, 
		RANK() OVER (PARTITION BY a.customer_id ORDER BY a.order_date ASC) AS item_order
	FROM sales a
	JOIN menu b
	ON a.product_id = b.product_id
	) orders
WHERE item_order = 1;

--Solution 2: Gets first item listed for the first visit of each customer.
	--Makes a (potentially erroneous) assumption that the first order listed in the database is the first item ordered.
SELECT customer_id, product_name
FROM(
	SELECT a.customer_id, a.order_date, b.product_name, 
		ROW_NUMBER() OVER (PARTITION BY a.customer_id ORDER BY a.order_date ASC) AS item_order
	FROM sales a
	JOIN menu b
	ON a.product_id = b.product_id
	) orders
WHERE item_order = 1;
	
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT b.product_name, COUNT(a.product_id) AS times_ordered
FROM sales a
JOIN menu b
ON a.product_id = b.product_id
GROUP BY b.product_name
ORDER BY COUNT(a.product_id) DESC
LIMIT 1;
	
-- 5. Which item was the most popular for each customer?
SELECT customer_id, product_name, times_ordered, favorite_rank
FROM (
	SELECT a.customer_id, b.product_name, COUNT(a.product_id) AS times_ordered,
		RANK() OVER (PARTITION BY a.customer_id ORDER BY COUNT(a.customer_id) DESC) AS favorite_rank
	FROM sales a
	JOIN menu b
	ON a.product_id = b.product_id
	GROUP BY a.customer_id, b.product_name
	ORDER BY a.customer_id, times_ordered DESC
	) favorites
WHERE favorite_rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
	-- Note: Customer A both ordered food and became a member on the same day. 
	-- Lack of timestamp data leaves us unable to determine the specific order of events.
	-- For this question, I will assume that they became a member first so they could earn loyalty points on their purchase.
SELECT orders.customer_id, orders.join_date, b.product_name, orders.order_date
FROM(
	SELECT a.customer_id, a.join_date, b.order_date, b.product_id,
		RANK() OVER (PARTITION BY a.customer_id ORDER BY order_date ASC) as orders_after_member
	FROM members a
	LEFT JOIN sales b
	ON a.customer_id = b.customer_id
	WHERE a.join_date <= b.order_date
	) orders
JOIN menu b
ON orders.product_id = b.product_id
WHERE orders_after_member = 1
ORDER BY orders.customer_id ASC;

		--Challenge: Use subquery instead of joins? See if its faster
		SELECT

-- 7. Which item was purchased just before the customer became a member?
SELECT orders.customer_id, orders.join_date, b.product_name, orders.order_date
FROM(
	SELECT a.customer_id, a.join_date, b.order_date, b.product_id,
		RANK() OVER (PARTITION BY a.customer_id ORDER BY order_date DESC) as orders_before_member
	FROM members a
	LEFT JOIN sales b
	ON a.customer_id = b.customer_id
	WHERE a.join_date > b.order_date
	) orders
JOIN menu b
ON orders.product_id = b.product_id
WHERE orders_before_member = 1
ORDER BY orders.customer_id ASC;
	
-- 8. What is the total items and amount spent for each member before they became a member?
SELECT a.customer_id, COUNT(a.product_id) AS items_purchased, SUM(price) AS total_spent
FROM sales a
LEFT JOIN members b
ON a.customer_id = b.customer_id
LEFT JOIN menu c
ON a.product_id = c.product_id
WHERE a.order_date < b.join_date
GROUP BY a.customer_id
ORDER BY a.customer_id ASC;
		
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- Solution 1: This takes the question as written and calculates how many points each customer would have based on their orders
SELECT a.customer_id,
	SUM(CASE
			WHEN a.product_id = 1 THEN b.price * 20
			ELSE b.price * 10
		END
		) AS total_points
FROM sales a
LEFT JOIN menu b
ON a.product_id = b.product_id
GROUP BY a.customer_id
ORDER BY a.customer_id ASC

--Solution 2: This assumes that only members of the loyalty program would earn points, and only calculates points for orders after joining.
SELECT a.customer_id,
	SUM(CASE
			WHEN a.product_id = 1 THEN b.price * 20
			ELSE b.price * 10
		END
		) AS total_points
FROM sales a
LEFT JOIN menu b
ON a.product_id = b.product_id
LEFT JOIN members c
ON a.customer_id = c.customer_id
WHERE a.order_date >= c.join_date
GROUP BY a.customer_id
ORDER BY a.customer_id ASC


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT a.customer_id,
	SUM(CASE
			WHEN a.product_id = 1 THEN b.price * 20
			WHEN a.product_id != 1 AND a.order_date BETWEEN c.join_date AND (c.join_date + 7) THEN b.price * 20
			ELSE b.price * 10
		END
		) AS total_points
FROM sales a
LEFT JOIN menu b
ON a.product_id = b.product_id
LEFT JOIN members c
ON a.customer_id = c.customer_id
WHERE a.customer_id IN ('A','B')
AND a.order_date BETWEEN c.join_date AND '1-31-2021'
GROUP BY a.customer_id
ORDER BY a.customer_id ASC
