CREATE OR REPLACE PACKAGE product_pkg AS

	PROCEDURE add
	(
		p_user_id     product.user_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_units       product.units%TYPE,
		p_unit_price  product.unit_price%TYPE
	);

	PROCEDURE edit
	(
		p_id          product.product_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_unit_price  product.unit_price%TYPE
	);

	PROCEDURE edit_units
	(
		p_id       product.product_id%TYPE,
		p_quantity product.units%TYPE
	);

	PROCEDURE remove(p_id product.product_id%TYPE);

	FUNCTION get(p_id product.product_id%TYPE) RETURN product%ROWTYPE;

	PROCEDURE exist(p_id product.product_id%TYPE);

END product_pkg;
/
CREATE OR REPLACE PACKAGE BODY product_pkg AS

	PROCEDURE check_format_name
	(
		p_name       product.name%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
		
	) IS
		match_regex  BOOLEAN := regexp_like(p_name, '^[a-zA-Z0-9 -]{4,30}$');
		invalid_name EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_name IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_name;
			END IF;
		ELSE
			IF p_name IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_name;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_name THEN
			raise_application_error(-20027, 'Nome do produto inválido.');
	END check_format_name;

	PROCEDURE check_format_description
	(
		p_description product.description%TYPE,
		p_allow_null  BOOLEAN DEFAULT FALSE
	) IS
		match_regex         BOOLEAN := regexp_like(p_description,
												   '^[a-zA-Z0-9,\. -]{10,120}$');
		invalid_description EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_description IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_description;
			END IF;
		ELSE
			IF p_description IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_description;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_description THEN
			raise_application_error(-20028, 'Descrição inválida.');
	END check_format_description;

	PROCEDURE check_format_category
	(
		p_category   product.category%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		valid_category   BOOLEAN := upper(p_category) IN
									('INFORMATICA',
									 'ELETRODOMESTICOS',
									 'ALIMENTOS',
									 'OUTRO');
		invalid_category EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_category IS NULL OR
			   NOT valid_category
			THEN
				RAISE invalid_category;
			END IF;
		ELSE
			IF p_category IS NOT NULL AND
			   NOT valid_category
			THEN
				RAISE invalid_category;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_category THEN
			raise_application_error(-20029, 'Categoria inválida.');
	END check_format_category;

	PROCEDURE check_format_model
	(
		p_model      product.model%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		match_regex   BOOLEAN := regexp_like(p_model,
											 '^[a-zA-Z0-9 -]{5,20}$');
		invalid_model EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_model IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_model;
			END IF;
		ELSE
			IF p_model IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_model;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_model THEN
			raise_application_error(-20030, 'Modelo inválido.');
	END check_format_model;

	PROCEDURE check_format_units
	(
		p_units      product.units%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		is_integer        BOOLEAN := MOD(p_units, 1) = 0;
		is_positive       BOOLEAN := p_units > 0;
		non_integer_units EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_units IS NULL OR
			   (NOT is_integer AND NOT is_positive)
			THEN
				RAISE non_integer_units;
			END IF;
		ELSE
			IF p_units IS NOT NULL AND
			   (NOT is_integer AND NOT is_positive)
			THEN
				RAISE non_integer_units;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN non_integer_units THEN
			raise_application_error(-20031, 'Número de unidades inválido.');
	END check_format_units;

	FUNCTION truncate_unit_price(p_unit_price product.unit_price%TYPE)
		RETURN product.unit_price%TYPE IS
	BEGIN
		RETURN trunc(p_unit_price, 2);
	END truncate_unit_price;

	PROCEDURE insert_reg
	(
		p_user_id     product.user_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_units       product.units%TYPE,
		p_unit_price  product.unit_price%TYPE
	) IS
	BEGIN
		INSERT INTO product
		VALUES
			(product_seq.nextval,
			 p_user_id,
			 upper(p_name),
			 p_description,
			 upper(p_category),
			 upper(p_model),
			 p_units,
			 p_unit_price);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_user_id     product.user_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_units       product.units%TYPE,
		p_unit_price  product.unit_price%TYPE
	) IS
		unit_price product.unit_price%TYPE;
	BEGIN
		end_user_pkg.exist(p_user_id);
	
		check_format_name(p_name);
		check_format_description(p_description);
		check_format_category(p_category);
		check_format_model(p_model, TRUE);
		check_format_units(p_units);
		unit_price := truncate_unit_price(p_unit_price);
	
		insert_reg(p_user_id,
				   p_name,
				   p_description,
				   p_category,
				   p_model,
				   p_units,
				   unit_price);
	END add;

	PROCEDURE exist(p_id product.product_id%TYPE) IS
		CURSOR check_exist IS
			SELECT 1 FROM product WHERE product_id = p_id;
		exist                NUMBER;
		non_existent_product EXCEPTION;
	BEGIN
		OPEN check_exist;
		FETCH check_exist
			INTO exist;
		CLOSE check_exist;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_product;
		END IF;
	
	EXCEPTION
		WHEN non_existent_product THEN
			raise_application_error(-20032, 'Produto inexistente.');
	END exist;

	PROCEDURE update_reg
	(
		p_id          product.product_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_unit_price  product.unit_price%TYPE
	) IS
	BEGIN
		UPDATE product
		SET    NAME        = nvl(upper(p_name), NAME),
			   description = nvl(p_description, description),
			   category    = nvl(upper(p_category), category),
			   model       = nvl(upper(p_model), model),
			   unit_price  = nvl(p_unit_price, unit_price)
		WHERE  product_id = p_id;
		COMMIT;
	END update_reg;

	PROCEDURE edit
	(
		p_id          product.product_id%TYPE,
		p_name        product.name%TYPE,
		p_description product.description%TYPE,
		p_category    product.category%TYPE,
		p_model       product.model%TYPE,
		p_unit_price  product.unit_price%TYPE
	) IS
		unit_price product.unit_price%TYPE;
	BEGIN
		exist(p_id);
		check_format_name(p_name, TRUE);
		check_format_description(p_description, TRUE);
		check_format_category(p_category, TRUE);
		check_format_model(p_model, TRUE);
		unit_price := truncate_unit_price(p_unit_price);
	
		update_reg(p_id,
				   p_name,
				   p_description,
				   p_category,
				   p_model,
				   unit_price);
	
	END edit;

	PROCEDURE edit_units
	(
		p_id       product.product_id%TYPE,
		p_quantity product.units%TYPE
	) IS
		invalid_quantity EXCEPTION;
	BEGIN
		IF p_quantity > 0
		THEN
			UPDATE product SET units = p_quantity WHERE product_id = p_id;
			COMMIT;
		ELSE
			RAISE invalid_quantity;
		END IF;
	
	EXCEPTION
		WHEN invalid_quantity THEN
			raise_application_error(-20033,
									'Quantidade de unidades inválida.');
	END edit_units;

	PROCEDURE remove(p_id product.product_id%TYPE) IS
	BEGIN
		DELETE FROM product WHERE product_id = p_id;
		COMMIT;
	END remove;

	FUNCTION get(p_id product.product_id%TYPE) RETURN product%ROWTYPE IS
		CURSOR get_product IS
			SELECT * FROM product WHERE product_id = p_id;
		product_ product%ROWTYPE;
	BEGIN
		exist(p_id);
	
		OPEN get_product;
		FETCH get_product
			INTO product_;
		CLOSE get_product;
	
		RETURN product_;
	END get;

END product_pkg;
/
