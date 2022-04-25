CREATE OR REPLACE PACKAGE address_pkg AS

	PROCEDURE add
	(
		p_user_id     address.user_id%TYPE,
		p_country_id  address.country_id%TYPE,
		p_state_id    address.state_id%TYPE,
		p_city_id     address.city_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	);

	PROCEDURE edit
	(
		p_id          address.address_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	);

	PROCEDURE remove(p_id address.address_id%TYPE);

	PROCEDURE exist(p_id address.address_id%TYPE);

	FUNCTION get(p_id address.address_id%TYPE) RETURN address%ROWTYPE;

END address_pkg;
/
CREATE OR REPLACE PACKAGE BODY address_pkg AS

	PROCEDURE check_format_street_name
	(
		p_street_name address.street_name%TYPE,
		p_allow_null  BOOLEAN DEFAULT FALSE
	) IS
		invalid_street_name EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_street_name IS NULL OR
			   NOT regexp_like(p_street_name, '^[[:alpha:] ]+\,\d+$')
			THEN
				RAISE invalid_street_name;
			END IF;
		ELSE
			IF p_street_name IS NOT NULL AND
			   NOT regexp_like(p_street_name, '^[[:alpha:] ]+\,\d+$')
			THEN
				RAISE invalid_street_name;
			END IF;
		END IF;
	EXCEPTION
		WHEN invalid_street_name THEN
			raise_application_error(-20021, 'Rua e número inválidos.');
	END check_format_street_name;

	FUNCTION remove_mask_zip_code(p_zip_code address.zip_code%TYPE)
		RETURN address.zip_code%TYPE IS
	BEGIN
		RETURN regexp_replace(p_zip_code, '[-]', '');
	END remove_mask_zip_code;

	PROCEDURE check_format_zip_code
	(
		p_zip_code   address.zip_code%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		invalid_zip_code EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_zip_code IS NULL OR
			   NOT regexp_like(p_zip_code, '^\d{8}$')
			THEN
				RAISE invalid_zip_code;
			END IF;
		ELSE
			IF p_zip_code IS NOT NULL AND
			   NOT regexp_like(p_zip_code, '^\d{8}$')
			THEN
				RAISE invalid_zip_code;
			END IF;
		END IF;
	EXCEPTION
		WHEN invalid_zip_code THEN
			raise_application_error(-20022, 'CEP inválido.');
	END check_format_zip_code;

	PROCEDURE check_state_in_country
	(
		p_state_id   address.state_id%TYPE,
		p_country_id address.country_id%TYPE
	) IS
		CURSOR get_state_in_country IS
			SELECT 1
			FROM   state
			WHERE  state_id = p_state_id AND
				   country_id = p_country_id;
		valid NUMBER;
		invalid_state EXCEPTION;
	BEGIN
		OPEN get_state_in_country;
		FETCH get_state_in_country
			INTO valid;
		CLOSE get_state_in_country;
	
		IF valid IS NULL
		THEN
			RAISE invalid_state;
		END IF;
	
	EXCEPTION
		WHEN invalid_state THEN
			raise_application_error(-20023, 'Estado inválido.');
	END check_state_in_country;

	PROCEDURE check_city_in_state
	(
		p_city_id  address.city_id%TYPE,
		p_state_id address.state_id%TYPE
	) IS
		CURSOR get_city_in_state IS
			SELECT 1
			FROM   city
			WHERE  city_id = p_city_id AND
				   state_id = p_state_id;
		valid NUMBER;
		invalid_city EXCEPTION;
	BEGIN
		OPEN get_city_in_state;
		FETCH get_city_in_state
			INTO valid;
		CLOSE get_city_in_state;
	
		IF valid IS NULL
		THEN
			RAISE invalid_city;
		END IF;
	
	EXCEPTION
		WHEN invalid_city THEN
			raise_application_error(-20024, 'Cidade inválida.');
	END check_city_in_state;

	PROCEDURE insert_reg
	(
		p_user_id     address.user_id%TYPE,
		p_country_id  address.country_id%TYPE,
		p_state_id    address.state_id%TYPE,
		p_city_id     address.city_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	) IS
	BEGIN
		INSERT INTO address
		VALUES
			(address_seq.nextval,
			 p_user_id,
			 p_country_id,
			 p_state_id,
			 p_city_id,
			 upper(p_street_name),
			 p_zip_code);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_user_id     address.user_id%TYPE,
		p_country_id  address.country_id%TYPE,
		p_state_id    address.state_id%TYPE,
		p_city_id     address.city_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	) IS
		zip_code address.zip_code%TYPE := remove_mask_zip_code(p_zip_code);
	BEGIN
		end_user_pkg.exist(p_user_id);
		country_pkg.exist(p_country_id);
		state_pkg.exist(p_state_id);
		city_pkg.exist(p_city_id);
	
		check_state_in_country(p_state_id, p_country_id);
		check_city_in_state(p_city_id, p_state_id);
	
		check_format_street_name(p_street_name);
		check_format_zip_code(zip_code);
	
		insert_reg(p_user_id,
				   p_country_id,
				   p_state_id,
				   p_city_id,
				   p_street_name,
				   zip_code);
	END add;

	PROCEDURE exist(p_id address.address_id%TYPE) IS
		CURSOR check_exist IS
			SELECT 1 FROM address WHERE address_id = p_id;
		exist NUMBER;
		non_existent_address EXCEPTION;
	BEGIN
		OPEN check_exist;
		FETCH check_exist
			INTO exist;
		CLOSE check_exist;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_address;
		END IF;
	
	EXCEPTION
		WHEN non_existent_address THEN
			raise_application_error(-20025, 'Endereço inexistente.');
	END exist;

	PROCEDURE update_reg
	(
		p_id          address.address_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	) IS
	BEGIN
		UPDATE address
		SET    street_name = nvl(street_name, p_street_name),
			   zip_code    = nvl(zip_code, p_zip_code)
		WHERE  address_id = p_id;
		COMMIT;
	END update_reg;

	PROCEDURE edit
	(
		p_id          address.address_id%TYPE,
		p_street_name address.street_name%TYPE,
		p_zip_code    address.zip_code%TYPE
	) IS
		zip_code address.zip_code%TYPE := remove_mask_zip_code(p_zip_code);
	BEGIN
		exist(p_id);
	
		check_format_street_name(p_street_name, TRUE);
		check_format_zip_code(zip_code, TRUE);
	
		update_reg(p_id, p_street_name, zip_code);
	END edit;

	PROCEDURE remove(p_id address.address_id%TYPE) IS
	BEGIN
		exist(p_id);
	
		DELETE FROM address WHERE address_id = p_id;
		COMMIT;
	END;

	FUNCTION get(p_id address.address_id%TYPE) RETURN address%ROWTYPE IS
		CURSOR get_address IS
			SELECT * FROM address WHERE address_id = p_id;
		address_ address%ROWTYPE;
	BEGIN
		exist(p_id);
	
		OPEN get_address;
		FETCH get_address
			INTO address_;
		CLOSE get_address;
	
		RETURN address_;
	END get;

END address_pkg;
/
