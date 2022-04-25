CREATE OR REPLACE PACKAGE shopping_cart_pkg AS

	TYPE item_list IS TABLE OF shopping_cart%ROWTYPE INDEX BY PLS_INTEGER;

	PROCEDURE add_product
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE DEFAULT 1
	);

	PROCEDURE edit_product_quantity
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE
	);

	PROCEDURE remove_product
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE
	);

	FUNCTION get_all_cart_items(p_user_id shopping_cart.user_id%TYPE)
		RETURN item_list;

END shopping_cart_pkg;
/
CREATE OR REPLACE PACKAGE BODY shopping_cart_pkg AS

	PROCEDURE check_own_product
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE
	) IS
		CURSOR get_product_owner IS
			SELECT p.user_id
			FROM   product p
			WHERE  p.product_id = p_product_id;
		product_owner product.user_id%TYPE;
		own_product_on_cart EXCEPTION;
	BEGIN
		OPEN get_product_owner;
		FETCH get_product_owner
			INTO product_owner;
		CLOSE get_product_owner;
	
		IF product_owner = p_user_id
		THEN
			RAISE own_product_on_cart;
		END IF;
	EXCEPTION
		WHEN own_product_on_cart THEN
			raise_application_error(-20034,
									'Não é possível adicionar próprio produto ao carrinho.');
	END check_own_product;

	PROCEDURE check_valid_quantity
	(
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE
	) IS
		units product.units%TYPE := product_pkg.get(p_product_id).units;
		invalid_quantity EXCEPTION;
	BEGIN
		IF p_quantity < 0 OR
		   p_quantity > units
		THEN
			RAISE invalid_quantity;
		END IF;
	
	EXCEPTION
		WHEN invalid_quantity THEN
			raise_application_error(-20035, 'Quantidade inválida.');
	END check_valid_quantity;

	FUNCTION get_total_price
	(
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE
	) RETURN shopping_cart.total_price%TYPE IS
		unit_price product.unit_price%TYPE := product_pkg.get(p_product_id).unit_price;
	BEGIN
		RETURN unit_price * p_quantity;
	END get_total_price;

	FUNCTION check_product_in_cart
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE
	) RETURN BOOLEAN IS
		CURSOR get_product IS
			SELECT 1
			FROM   product p
			INNER  JOIN shopping_cart sc
			ON     p.product_id = sc.product_id
			WHERE  sc.user_id = p_user_id AND
				   sc.product_id = p_product_id;
		exist NUMBER;
	BEGIN
		OPEN get_product;
		FETCH get_product
			INTO exist;
		CLOSE get_product;
	
		RETURN exist IS NOT NULL;
	END check_product_in_cart;

	FUNCTION get_cart_item
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE
	) RETURN shopping_cart%ROWTYPE IS
		CURSOR get_shopping_cart_item IS
			SELECT *
			FROM   shopping_cart
			WHERE  user_id = p_user_id AND
				   product_id = p_product_id;
		item shopping_cart%ROWTYPE;
	BEGIN
		OPEN get_shopping_cart_item;
		FETCH get_shopping_cart_item
			INTO item;
		CLOSE get_shopping_cart_item;
	
		RETURN item;
	END get_cart_item;

	PROCEDURE insert_reg
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE
	) IS
		total_price shopping_cart.total_price%TYPE := get_total_price(p_product_id,
																	  p_quantity);
	BEGIN
		INSERT INTO shopping_cart
		VALUES
			(p_user_id, p_product_id, p_quantity, total_price);
		COMMIT;
	END insert_reg;

	PROCEDURE add_product
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE DEFAULT 1
	) IS
		quantity shopping_cart.quantity%TYPE;
	BEGIN
		end_user_pkg.exist(p_user_id);
		product_pkg.exist(p_product_id);
	
		check_own_product(p_user_id, p_product_id);
		check_valid_quantity(p_product_id, p_quantity);
	
		IF check_product_in_cart(p_user_id, p_product_id)
		THEN
			quantity := get_cart_item(p_user_id, p_product_id).quantity;
			edit_product_quantity(p_user_id,
								  p_product_id,
								  quantity + p_quantity);
		ELSE
			insert_reg(p_user_id, p_product_id, p_quantity);
		END IF;
	END add_product;

	PROCEDURE edit_product_quantity
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE,
		p_quantity   shopping_cart.quantity%TYPE
	) IS
		l_total_price shopping_cart.total_price%TYPE;
	BEGIN
		end_user_pkg.exist(p_user_id);
		product_pkg.exist(p_product_id);
		check_valid_quantity(p_product_id, p_quantity);
	
		l_total_price := get_total_price(p_product_id, p_quantity);
	
		UPDATE shopping_cart
		SET    quantity = p_quantity, total_price = l_total_price
		WHERE  user_id = p_user_id AND
			   product_id = p_product_id;
		COMMIT;
	END edit_product_quantity;

	PROCEDURE remove_product
	(
		p_user_id    shopping_cart.user_id%TYPE,
		p_product_id shopping_cart.product_id%TYPE
	) IS
	BEGIN
		end_user_pkg.exist(p_user_id);
		product_pkg.exist(p_product_id);
	
		DELETE FROM shopping_cart
		WHERE  user_id = p_user_id AND
			   product_id = p_product_id;
		COMMIT;
	END remove_product;

	FUNCTION get_all_cart_items(p_user_id shopping_cart.user_id%TYPE)
		RETURN item_list IS
		CURSOR get_all_items IS
			SELECT sc.*
			FROM   end_user u
			INNER  JOIN shopping_cart sc
			ON     u.user_id = sc.user_id
			INNER  JOIN product p
			ON     p.product_id = sc.product_id
			WHERE  sc.user_id = p_user_id;
		list item_list;
		empty_cart EXCEPTION;
		non_existent_user EXCEPTION;
	BEGIN
		end_user_pkg.exist(p_user_id);
	
		OPEN get_all_items;
		FETCH get_all_items BULK COLLECT
			INTO list;
		CLOSE get_all_items;
	
		IF list.count = 0
		THEN
			RAISE empty_cart;
		END IF;
	
		RETURN list;
	
	EXCEPTION
		WHEN empty_cart THEN
			raise_application_error(-20036, 'Carrinho vazio.');
	END get_all_cart_items;

END shopping_cart_pkg;
/
