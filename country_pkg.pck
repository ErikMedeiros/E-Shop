CREATE OR REPLACE PACKAGE country_pkg AS

	PROCEDURE add
	(
		p_code country.code%TYPE,
		p_ddi  country.ddi%TYPE,
		p_name country.name%TYPE
	);

	PROCEDURE lock_country(p_id country.country_id%TYPE);

	PROCEDURE unlock_country(p_id country.country_id%TYPE);

	PROCEDURE exist(p_id country.country_id%TYPE);

	FUNCTION get(p_id country.country_id%TYPE) RETURN country%ROWTYPE;

END country_pkg;
/
CREATE OR REPLACE PACKAGE BODY country_pkg AS

	PROCEDURE check_format_code(p_code country.code%TYPE) IS
		invalid_country_code EXCEPTION;
	BEGIN
		IF p_code IS NULL OR
		   NOT regexp_like(p_code, '^[[:alpha:]]{3}$')
		THEN
			RAISE invalid_country_code;
		END IF;
	
	EXCEPTION
		WHEN invalid_country_code THEN
			raise_application_error(-20009, 'Código do país inválido.');
	END check_format_code;

	PROCEDURE check_exist_code(p_code country.code%TYPE) IS
		CURSOR get_code IS
			SELECT 1 FROM country WHERE code = upper(p_code);
		exist NUMBER;
		existing_code EXCEPTION;
	BEGIN
		OPEN get_code;
		FETCH get_code
			INTO exist;
		CLOSE get_code;
	
		IF exist IS NOT NULL
		THEN
			RAISE existing_code;
		END IF;
	
	EXCEPTION
		WHEN existing_code THEN
			raise_application_error(-20010, 'Código de país já existente.');
	END check_exist_code;

	PROCEDURE check_format_ddi(p_ddi country.ddi%TYPE) IS
		invalid_ddi EXCEPTION;
	BEGIN
		IF p_ddi IS NULL OR
		   NOT regexp_like(p_ddi, '^\d{1,3}$')
		THEN
			RAISE invalid_ddi;
		END IF;
	
	EXCEPTION
		WHEN invalid_ddi THEN
			raise_application_error(-20011, 'Código DDI inválido.');
	END check_format_ddi;

	PROCEDURE check_exist_ddi(p_ddi country.ddi%TYPE) IS
		CURSOR get_ddi IS
			SELECT 1 FROM country WHERE ddi = p_ddi;
		exist NUMBER;
		existing_ddi EXCEPTION;
	BEGIN
		OPEN get_ddi;
		FETCH get_ddi
			INTO exist;
		CLOSE get_ddi;
	
		IF exist IS NOT NULL
		THEN
			RAISE existing_ddi;
		END IF;
	
	EXCEPTION
		WHEN existing_ddi THEN
			raise_application_error(-20012, 'DDI já existente.');
	END check_exist_ddi;

	PROCEDURE check_format_name(p_name country.name%TYPE) IS
		invalid_name EXCEPTION;
	BEGIN
		IF p_name IS NULL OR
		   NOT regexp_like(p_name, '^[[:alpha:]]+( [[:alpha:]]+)*$')
		THEN
			RAISE invalid_name;
		END IF;
	
	EXCEPTION
		WHEN invalid_name THEN
			raise_application_error(-20013, 'Nome do país inválido.');
	END check_format_name;

	PROCEDURE insert_reg
	(
		p_code country.code%TYPE,
		p_ddi  country.ddi%TYPE,
		p_name country.name%TYPE
	) IS
	BEGIN
		INSERT INTO country
		VALUES
			(country_seq.nextval, upper(p_code), p_ddi, upper(p_name), 0);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_code country.code%TYPE,
		p_ddi  country.ddi%TYPE,
		p_name country.name%TYPE
	) IS
	BEGIN
		check_format_code(p_code);
		check_format_ddi(p_ddi);
		check_format_name(p_name);
	
		check_exist_code(p_code);
		check_exist_ddi(p_ddi);
	
		insert_reg(p_code, p_ddi, p_name);
	END add;

	PROCEDURE exist(p_id country.country_id%TYPE) IS
		CURSOR get_country IS
			SELECT 1 FROM country WHERE country_id = p_id;
		exist NUMBER;
		non_existent_country EXCEPTION;
	BEGIN
		OPEN get_country;
		FETCH get_country
			INTO exist;
		CLOSE get_country;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_country;
		END IF;
	
	EXCEPTION
		WHEN non_existent_country THEN
			raise_application_error(-20014, 'País inexistente.');
	END exist;

	PROCEDURE lock_country(p_id country.country_id%TYPE) IS
		CURSOR get_all_states IS
			SELECT state_id FROM state WHERE country_id = p_id;
		CURSOR get_all_unlocked_country_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.country_id = p_id AND
				   u.locked = 0;
	BEGIN
		exist(p_id);
	
		UPDATE country SET locked = 1 WHERE country_id = p_id;
		COMMIT;
	
		-- LOCK ALL STATES WITHIN THE COUNTRY
		FOR s IN get_all_states LOOP
			state_pkg.lock_state(s.state_id);
		END LOOP;
	
		-- LOCK ALL USERS THAT HAVE ADDRESS ON LOCKED COUNTRY
		FOR u IN get_all_unlocked_country_users LOOP
			end_user_pkg.lock_user(u.user_id);
		END LOOP;
	END lock_country;

	PROCEDURE unlock_country(p_id country.country_id%TYPE) IS
		CURSOR get_all_states IS
			SELECT state_id FROM state WHERE country_id = p_id;
		CURSOR get_all_locked_country_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.country_id = p_id AND
				   u.locked = 1;
	BEGIN
		exist(p_id);
	
		UPDATE country SET locked = 0 WHERE country_id = p_id;
		COMMIT;
	
		-- UNLOCK ALL STATES WITHIN THE COUNTRY
		FOR s IN get_all_states LOOP
			state_pkg.unlock_state(s.state_id);
		END LOOP;
	
		-- UNLOCK ALL USERS THAT HAVE ADDRESS ON UNLOCKED COUNTRY
		FOR u IN get_all_locked_country_users LOOP
			end_user_pkg.unlock_user(u.user_id);
		END LOOP;
	END unlock_country;

	FUNCTION get(p_id country.country_id%TYPE) RETURN country%ROWTYPE IS
		CURSOR get_country IS
			SELECT * FROM country WHERE country_id = p_id;
		country_ country%ROWTYPE;
	BEGIN
		OPEN get_country;
		FETCH get_country
			INTO country_;
		CLOSE get_country;
	
		RETURN country_;
	END get;

END country_pkg;
/
