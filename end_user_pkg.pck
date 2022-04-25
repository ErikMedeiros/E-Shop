CREATE OR REPLACE PACKAGE end_user_pkg AS

	PROCEDURE add
	(
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE,
		p_cpf        end_user.cpf%TYPE
	);

	PROCEDURE edit
	(
		p_id         end_user.user_id%TYPE,
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE
	);

	PROCEDURE lock_user(p_id end_user.user_id%TYPE);

	PROCEDURE unlock_user(p_id end_user.user_id%TYPE);

	PROCEDURE exist(p_id end_user.user_id%TYPE);

	FUNCTION get(p_id end_user.user_id%TYPE) RETURN end_user%ROWTYPE;

END end_user_pkg;
/
CREATE OR REPLACE PACKAGE BODY end_user_pkg AS

	PROCEDURE check_format_cpf(p_cpf end_user.cpf%TYPE) IS
		total NUMBER := 0;
		digit NUMBER := 0;
		invalid_cpf EXCEPTION;
	BEGIN
		IF NOT regexp_like(p_cpf, '^\d{11}$')
		THEN
			RAISE invalid_cpf;
		END IF;
	
		FOR i IN 1 .. 9 LOOP
			total := total + substr(p_cpf, i, 1) * (11 - i);
		END LOOP;
	
		digit := 11 - MOD(total, 11);
	
		IF digit > 9
		THEN
			digit := 0;
		END IF;
	
		IF digit != substr(p_cpf, 10, 1)
		THEN
			RAISE invalid_cpf;
		END IF;
	
		--digit := 0;
		total := 0;
	
		FOR i IN 1 .. 10 LOOP
			total := total + substr(p_cpf, i, 1) * (12 - i);
		END LOOP;
	
		digit := 11 - MOD(total, 11);
	
		IF digit > 9
		THEN
			digit := 0;
		END IF;
	
		IF digit != substr(p_cpf, 11, 1)
		THEN
			RAISE invalid_cpf;
		END IF;
	
	EXCEPTION
		WHEN invalid_cpf THEN
			raise_application_error(-20000, 'Cpf inválido.');
	END check_format_cpf;

	PROCEDURE check_exist_cpf(p_cpf end_user.cpf%TYPE) IS
		CURSOR check_exist IS
			SELECT 1 FROM end_user WHERE cpf = p_cpf;
		exist NUMBER;
		existing_cpf EXCEPTION;
	BEGIN
		OPEN check_exist;
		FETCH check_exist
			INTO exist;
		CLOSE check_exist;
	
		IF exist IS NOT NULL
		THEN
			RAISE existing_cpf;
		END IF;
	
	EXCEPTION
		WHEN existing_cpf THEN
			raise_application_error(-20001, 'Cpf já existente.');
	END check_exist_cpf;

	FUNCTION remove_mask_cpf(p_cpf end_user.cpf%TYPE) RETURN end_user.cpf%TYPE IS
	BEGIN
		RETURN regexp_replace(p_cpf, '[.-]', '');
	END remove_mask_cpf;

	PROCEDURE check_format_email
	(
		p_email      end_user.email%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		match_regex BOOLEAN := regexp_like(p_email,
										   '^[A-Za-z]+[A-Za-z0-9.]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$');
		invalid_email EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_email IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_email;
			END IF;
		ELSE
			IF p_email IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_email;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_email THEN
			raise_application_error(-20002, 'Email inválido.');
	END check_format_email;

	PROCEDURE check_exist_email(p_email end_user.email%TYPE) IS
		CURSOR check_exist IS
			SELECT 1 FROM end_user WHERE email = upper(p_email);
		exist NUMBER;
		existing_email EXCEPTION;
	BEGIN
		OPEN check_exist;
		FETCH check_exist
			INTO exist;
		CLOSE check_exist;
	
		IF exist IS NOT NULL
		THEN
			RAISE existing_email;
		END IF;
	
	EXCEPTION
		WHEN existing_email THEN
			raise_application_error(-20003, 'Email já existente.');
	END check_exist_email;

	PROCEDURE check_format_names
	(
		p_first_name VARCHAR2,
		p_last_name  VARCHAR2,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		match_first_name BOOLEAN := regexp_like(p_first_name,
												'^[[:alpha:]]{2,15}$');
		match_last_name BOOLEAN := regexp_like(p_last_name,
											   '^[[:alpha:]]{2,15}$');
		invalid_first_name EXCEPTION;
		invalid_last_name EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_first_name IS NULL OR
			   NOT match_first_name
			THEN
				RAISE invalid_first_name;
			END IF;
		
			IF p_last_name IS NULL OR
			   NOT match_last_name
			THEN
				RAISE invalid_last_name;
			END IF;
		ELSE
			IF p_first_name IS NOT NULL AND
			   NOT match_first_name
			THEN
				RAISE invalid_first_name;
			END IF;
		
			IF p_last_name IS NOT NULL AND
			   NOT match_last_name
			THEN
				RAISE invalid_last_name;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_first_name THEN
			raise_application_error(-20004, 'Primeiro nome inválido.');
		WHEN invalid_last_name THEN
			raise_application_error(-20005, 'Segundo nome inválido.');
	END check_format_names;

	PROCEDURE check_format_phone
	(
		p_number     end_user.tel_1%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		match_regex BOOLEAN := regexp_like(p_number, '^\d{11}$');
		invalid_phone EXCEPTION;
	BEGIN
		IF NOT p_allow_null
		THEN
			IF p_number IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_phone;
			END IF;
		ELSE
			IF p_number IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_phone;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_phone THEN
			raise_application_error(-20006, 'Telefone inválido.');
	END check_format_phone;

	FUNCTION remove_mask_phone(p_number end_user.tel_1%TYPE)
		RETURN end_user.tel_1%TYPE IS
	BEGIN
		RETURN regexp_replace(p_number, '[\(\)-]', '');
	END remove_mask_phone;

	PROCEDURE check_format_password
	(
		p_password   end_user.password%TYPE,
		p_allow_null BOOLEAN DEFAULT FALSE
	) IS
		match_length BOOLEAN := regexp_like(p_password, '^.{8,32}$');
		match_digits BOOLEAN := regexp_like(p_password, '(.*[0-9])');
		match_lower BOOLEAN := regexp_like(p_password, '(.*[a-z])');
		match_upper BOOLEAN := regexp_like(p_password, '(.*[A-Z])');
		match_punct BOOLEAN := regexp_like(p_password, '(.*[[:punct:]])');
	
		-- ^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[[:punct:]]).{8,32}$
		-- This matches the above regex because Oracle does not support positive lookahead.
		match_regex BOOLEAN := match_length AND match_digits AND
							   match_lower AND match_upper AND match_punct;
		invalid_password EXCEPTION;
	BEGIN
	
		IF NOT p_allow_null
		THEN
			IF p_password IS NULL OR
			   NOT match_regex
			THEN
				RAISE invalid_password;
			END IF;
		ELSE
			IF p_password IS NOT NULL AND
			   NOT match_regex
			THEN
				RAISE invalid_password;
			END IF;
		END IF;
	
	EXCEPTION
		WHEN invalid_password THEN
			raise_application_error(-20007, 'Senha inválida.');
	END check_format_password;
    
	PROCEDURE exist(p_id end_user.user_id%TYPE) IS
		CURSOR get_user_exist IS
			SELECT 1 FROM end_user WHERE user_id = p_id;
		exist NUMBER;
		non_existent_user EXCEPTION;
	BEGIN
		OPEN get_user_exist;
		FETCH get_user_exist
			INTO exist;
		CLOSE get_user_exist;
	
		IF exist IS NULL
		THEN
			RAISE non_existent_user;
		END IF;
	
	EXCEPTION
		WHEN non_existent_user THEN
			raise_application_error(-20008, 'Usuário inexistente.');
	END exist;

	PROCEDURE insert_reg
	(
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE,
		p_cpf        end_user.cpf%TYPE
	) IS
	BEGIN
		INSERT INTO end_user
		VALUES
			(end_user_seq.nextval,
			 upper(p_first_name),
			 upper(p_last_name),
			 upper(p_email),
			 p_password,
			 p_tel_1,
			 p_tel_2,
			 p_cpf,
			 0);
		COMMIT;
	END insert_reg;

	PROCEDURE add
	(
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE,
		p_cpf        end_user.cpf%TYPE
	) IS
		tel_1 end_user.tel_1%TYPE := remove_mask_phone(p_tel_1);
		tel_2 end_user.tel_2%TYPE := remove_mask_phone(p_tel_2);
		cpf end_user.cpf%TYPE := remove_mask_cpf(p_cpf);
	BEGIN
		check_format_names(p_first_name, p_last_name);
		check_format_email(p_email);
		check_format_password(p_password);
		check_format_phone(tel_1, TRUE);
		check_format_phone(tel_2, TRUE);
		check_format_cpf(cpf);
	
		check_exist_email(p_email);
		check_exist_cpf(cpf);
	
		insert_reg(p_first_name,
				   p_last_name,
				   p_email,
				   p_password,
				   tel_1,
				   tel_2,
				   cpf);
	END add;

	PROCEDURE update_reg
	(
		p_id         end_user.user_id%TYPE,
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE
	) IS
	BEGIN
		UPDATE end_user
		SET    first_name = nvl(upper(p_first_name), first_name),
			   last_name  = nvl(upper(p_last_name), last_name),
			   email      = nvl(upper(p_email), email),
			   password   = nvl(p_password, password),
			   tel_1      = nvl(p_tel_1, tel_1),
			   tel_2      = nvl(p_tel_2, tel_2)
		WHERE  user_id = p_id;
		COMMIT;
	END update_reg;

	PROCEDURE edit
	(
		p_id         end_user.user_id%TYPE,
		p_first_name end_user.first_name%TYPE,
		p_last_name  end_user.last_name%TYPE,
		p_email      end_user.email%TYPE,
		p_password   end_user.password%TYPE,
		p_tel_1      end_user.tel_1%TYPE,
		p_tel_2      end_user.tel_2%TYPE
	) IS
		tel_1 end_user.tel_1%TYPE := remove_mask_phone(p_tel_1);
		tel_2 end_user.tel_2%TYPE := remove_mask_phone(p_tel_2);
	BEGIN
		exist(p_id);
	
		check_format_names(p_first_name, p_last_name, TRUE);
		check_format_email(p_email, TRUE);
		check_format_password(p_password, TRUE);
		check_format_phone(tel_1, TRUE);
		check_format_phone(tel_2, TRUE);
	
		IF p_email IS NOT NULL
		THEN
			check_exist_email(p_email);
		END IF;
	
		update_reg(p_id,
				   p_first_name,
				   p_last_name,
				   p_email,
				   p_password,
				   tel_1,
				   tel_2);
	END edit;

	PROCEDURE lock_user(p_id end_user.user_id%TYPE) IS
	BEGIN
		exist(p_id);
	
		UPDATE end_user SET locked = 1 WHERE user_id = p_id;
		COMMIT;
	END lock_user;

	PROCEDURE unlock_user(p_id end_user.user_id%TYPE) IS
	BEGIN
		exist(p_id);
	
		UPDATE end_user SET locked = 0 WHERE user_id = p_id;
		COMMIT;
	END unlock_user;

	FUNCTION get(p_id end_user.user_id%TYPE) RETURN end_user%ROWTYPE IS
		CURSOR get_user IS
			SELECT * FROM end_user WHERE user_id = p_id;
		user_ end_user%ROWTYPE;
	BEGIN
		exist(p_id);
	
		OPEN get_user;
		FETCH get_user
			INTO user_;
		CLOSE get_user;
	
		RETURN user_;
	END get;

END end_user_pkg;
/
