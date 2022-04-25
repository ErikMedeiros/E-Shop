CREATE OR REPLACE PACKAGE city_pkg AS

	PROCEDURE add
	(
		p_state_id city.state_id%TYPE,
		p_name     city.name%TYPE
	);

	PROCEDURE lock_city(p_id city.city_id%TYPE);

	PROCEDURE unlock_city(p_id city.city_id%TYPE);

	PROCEDURE exist(p_id city.city_id%TYPE);

	FUNCTION get(p_id city.city_id%TYPE) RETURN city%ROWTYPE;

END city_pkg;
/
CREATE OR REPLACE PACKAGE BODY city_pkg AS

	PROCEDURE check_format_name(p_name city.name%TYPE) IS
		invalid_name EXCEPTION;
	BEGIN
		IF p_name IS NULL OR
		   NOT regexp_like(p_name, '^[[:alpha:]]+( [[:alpha:]]+)*$')
		THEN
			RAISE invalid_name;
		END IF;
	
	EXCEPTION
		WHEN invalid_name THEN
			raise_application_error(-20018, 'Nome da cidade inválido.');
	END check_format_name;

	PROCEDURE insert_reg
	(
		p_state_id city.state_id%TYPE,
		p_name     city.name%TYPE
	) IS
	BEGIN
		INSERT INTO city
		VALUES
			(city_seq.nextval, p_state_id, upper(p_name), 0);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_state_id city.state_id%TYPE,
		p_name     city.name%TYPE
	) IS
	BEGIN
		state_pkg.exist(p_state_id);
	
		check_format_name(p_name);
		insert_reg(p_state_id, p_name);
	END add;

	PROCEDURE exist(p_id city.city_id%TYPE) IS
		CURSOR get_city IS
			SELECT 1 FROM city WHERE city_id = p_id;
		exist NUMBER;
		non_existent_city EXCEPTION;
	BEGIN
		OPEN get_city;
		FETCH get_city
			INTO exist;
		CLOSE get_city;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_city;
		END IF;
	
	EXCEPTION
		WHEN non_existent_city THEN
			raise_application_error(-20019, 'Cidade inexistente.');
	END exist;

	PROCEDURE lock_city(p_id city.city_id%TYPE) IS
		CURSOR get_all_unlocked_city_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.city_id = p_id AND
				   u.locked = 0;
	BEGIN
		exist(p_id);
	
		UPDATE city SET locked = 1 WHERE city_id = p_id;
	
		-- LOCK ALL USERS THAT HAVE ADDRESS ON LOCKED CITY
		FOR u IN get_all_unlocked_city_users LOOP
			end_user_pkg.lock_user(u.user_id);
		END LOOP;
	END lock_city;

	PROCEDURE unlock_city(p_id city.city_id%TYPE) IS
		CURSOR get_all_locked_city_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.city_id = p_id AND
				   u.locked = 1;
		state_locked NUMBER(1);
		locked_state EXCEPTION;
	BEGIN
		exist(p_id);
	
		SELECT s.locked
		INTO   state_locked
		FROM   state s
		INNER  JOIN city c
		ON     c.state_id = s.state_id
		WHERE  c.city_id = p_id;
	
		IF state_locked = 0
		THEN
			UPDATE city SET locked = 0 WHERE city_id = p_id;
			COMMIT;
		
			-- MUST UNLOCK ALL USERS THAT HAVE ADDRESS ON UNLOCKED CITY
			FOR u IN get_all_locked_city_users LOOP
				end_user_pkg.unlock_user(u.user_id);
			END LOOP;
		ELSE
			RAISE locked_state;
		END IF;
	
	EXCEPTION
		WHEN locked_state THEN
			raise_application_error(-20020,
									'Não é possível desbloquear cidade de um estado bloqueado.');
	END unlock_city;

	FUNCTION get(p_id city.city_id%TYPE) RETURN city%ROWTYPE IS
		CURSOR get_city IS
			SELECT * FROM city WHERE city_id = p_id;
		city_ city%ROWTYPE;
	BEGIN
		OPEN get_city;
		FETCH get_city
			INTO city_;
		CLOSE get_city;
	
		RETURN city_;
	END get;

END city_pkg;
/
