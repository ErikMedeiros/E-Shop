CREATE OR REPLACE PACKAGE orders_pkg AS

	PROCEDURE create_orders
	(
		p_user_id        orders.user_id%TYPE,
		p_payment_method orders.payment_method%TYPE
	);

	PROCEDURE exist(p_id orders.order_id%TYPE);

	FUNCTION get(p_id orders.order_id%TYPE) RETURN orders%ROWTYPE;

END orders_pkg;
/
CREATE OR REPLACE PACKAGE BODY orders_pkg AS

	PROCEDURE check_format_payment_method(p_payment_method orders.payment_method%TYPE) IS
		valid_method BOOLEAN := upper(p_payment_method) IN
								('CREDIT_CARD', 'DEBIT_CARD', 'BANK_SLIP');
		invalid_payment_method EXCEPTION;
	BEGIN
		IF NOT valid_method
		THEN
			RAISE invalid_payment_method;
		END IF;
	EXCEPTION
		WHEN invalid_payment_method THEN
			raise_application_error(-20037,
									'Método de pagamento inválido.');
	END check_format_payment_method;

	PROCEDURE insert_reg
	(
		p_user_id        orders.user_id%TYPE,
		p_product_id     orders.product_id%TYPE,
		p_quantity       orders.quantity%TYPE,
		p_total_price    orders.total_price%TYPE,
		p_payment_method orders.payment_method%TYPE
	) IS
	BEGIN
		INSERT INTO orders
		VALUES
			(orders_seq.nextval,
			 p_user_id,
			 p_product_id,
			 p_quantity,
			 p_total_price,
			 current_date,
			 upper(p_payment_method));
		COMMIT;
	END insert_reg;

	PROCEDURE create_orders
	(
		p_user_id        orders.user_id%TYPE,
		p_payment_method orders.payment_method%TYPE
	) IS
		list shopping_cart_pkg.item_list;
		item shopping_cart%ROWTYPE;
	BEGIN
		end_user_pkg.exist(p_user_id);
		check_format_payment_method(p_payment_method);
	
		list := shopping_cart_pkg.get_all_cart_items(p_user_id);
		FOR i IN list.first .. list.last LOOP
			item := list(i);
			insert_reg(item.user_id,
					   item.product_id,
					   item.quantity,
					   item.total_price,
					   p_payment_method);
			shopping_cart_pkg.remove_product(item.user_id, item.product_id);
		END LOOP;
	END create_orders;

	PROCEDURE exist(p_id orders.order_id%TYPE) IS
		CURSOR get_exist_order IS
			SELECT 1 FROM orders WHERE order_id = p_id;
		exist NUMBER;
		non_existent_order EXCEPTION;
	BEGIN
		OPEN get_exist_order;
		FETCH get_exist_order
			INTO exist;
		CLOSE get_exist_order;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_order;
		END IF;
	
	EXCEPTION
		WHEN non_existent_order THEN
			raise_application_error(-20038, 'Pedido inexistente.');
	END exist;

	FUNCTION get(p_id orders.order_id%TYPE) RETURN orders%ROWTYPE IS
		CURSOR get_order IS
			SELECT * FROM orders WHERE order_id = p_id;
		order_ orders%ROWTYPE;
	BEGIN
		exist(p_id);
	
		OPEN get_order;
		FETCH get_order
			INTO order_;
		CLOSE get_order;
	
		RETURN order_;
	END get;

END orders_pkg;
/
