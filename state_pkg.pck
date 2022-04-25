CREATE OR REPLACE PACKAGE state_pkg AS

	PROCEDURE add
	(
		p_country_id state.country_id%TYPE,
		p_name       state.name%TYPE
	);

	PROCEDURE lock_state(p_id state.state_id%TYPE);

	PROCEDURE unlock_state(p_id state.state_id%TYPE);

	PROCEDURE exist(p_id state.state_id%TYPE);

	FUNCTION get(p_id state.state_id%TYPE) RETURN state%ROWTYPE;

END state_pkg;
/
CREATE OR REPLACE PACKAGE BODY state_pkg AS

	PROCEDURE check_format_name(p_name state.name%TYPE) IS
		invalid_name EXCEPTION;
	BEGIN
		IF p_name IS NULL OR
		   NOT regexp_like(p_name, '^[[:alpha:]]+( [[:alpha:]]+)*$')
		THEN
			RAISE invalid_name;
		END IF;
	
	EXCEPTION
		WHEN invalid_name THEN
			raise_application_error(-20015, 'Nome do estado inválido.');
	END check_format_name;

	PROCEDURE insert_reg
	(
		p_country_id state.country_id%TYPE,
		p_name       state.name%TYPE
	) IS
	BEGIN
		INSERT INTO state
		VALUES
			(state_seq.nextval, p_country_id, upper(p_name), 0);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_country_id state.country_id%TYPE,
		p_name       state.name%TYPE
	) IS
	BEGIN
		country_pkg.exist(p_country_id);
	
		check_format_name(p_name);
		insert_reg(p_country_id, p_name);
	END add;

	PROCEDURE exist(p_id state.state_id%TYPE) IS
		CURSOR get_state IS
			SELECT 1 FROM state WHERE state_id = p_id;
		exist NUMBER;
		non_existent_state EXCEPTION;
	BEGIN
		OPEN get_state;
		FETCH get_state
			INTO exist;
		CLOSE get_state;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_state;
		END IF;
	
	EXCEPTION
		WHEN non_existent_state THEN
			raise_application_error(-20016, 'Estado inexistente.');
	END exist;

	PROCEDURE lock_state(p_id state.state_id%TYPE) IS
		CURSOR get_all_cities IS
			SELECT city_id FROM city WHERE state_id = p_id;
		CURSOR get_all_unlocked_state_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.state_id = p_id AND
				   u.locked = 0;
	BEGIN
		exist(p_id);
	
		UPDATE state SET locked = 1 WHERE state_id = p_id;
		COMMIT;
	
		-- LOCK ALL CITIES WITHIN THE STATE
		FOR c IN get_all_cities LOOP
			city_pkg.lock_city(c.city_id);
		END LOOP;
	
		-- LOCK ALL USERS THAT HAVE ADDRESS ON LOCKED STATE
		FOR u IN get_all_unlocked_state_users LOOP
			end_user_pkg.lock_user(u.user_id);
		END LOOP;
	END lock_state;

	PROCEDURE unlock_state(p_id state.state_id%TYPE) IS
		CURSOR get_all_cities IS
			SELECT city_id FROM city WHERE state_id = p_id;
		CURSOR get_all_locked_state_users IS
			SELECT u.user_id
			FROM   address a
			INNER  JOIN end_user u
			ON     u.user_id = a.user_id
			WHERE  a.state_id = p_id AND
				   u.locked = 1;
		country_locked NUMBER(1);
		locked_country EXCEPTION;
	BEGIN
		exist(p_id);
	
		SELECT c.locked
		INTO   country_locked
		FROM   country c
		INNER  JOIN state s
		ON     c.country_id = s.country_id
		WHERE  s.state_id = p_id;
	
		IF country_locked = 0
		THEN
			UPDATE state SET locked = 0 WHERE state_id = p_id;
			COMMIT;
		
			-- UNLOCK ALL CITIES WITHIN THE STATE
			FOR c IN get_all_cities LOOP
				city_pkg.unlock_city(c.city_id);
			END LOOP;
		
			-- UNLOCK ALL USERS THAT HAVE ADDRESS ON UNLOCKED STATE
			FOR u IN get_all_locked_state_users LOOP
				end_user_pkg.unlock_user(u.user_id);
			END LOOP;
		ELSE
			RAISE locked_country;
		END IF;
	
	EXCEPTION
		WHEN locked_country THEN
			raise_application_error(-20017,
									'Não é possível desbloquear estado de um país bloqueado.');
	END unlock_state;

	FUNCTION get(p_id state.state_id%TYPE) RETURN state%ROWTYPE IS
		CURSOR get_state IS
			SELECT * FROM state WHERE state_id = p_id;
		state_ state%ROWTYPE;
	BEGIN
		OPEN get_state;
		FETCH get_state
			INTO state_;
		CLOSE get_state;
	
		RETURN state_;
	END get;

END state_pkg;
/
