CREATE TABLE end_user (
    user_id NUMBER,
    first_name VARCHAR2(15) NOT NULL,
    last_name VARCHAR2(15) NOT NULL,
    email VARCHAR2(30) NOT NULL,
    password VARCHAR2(30) NOT NULL,
    tel_1 VARCHAR2(11),
    tel_2 VARCHAR2(11),
    cpf varchar2(11),
    locked number(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pk_user_id PRIMARY KEY (user_id),
    CONSTRAINT unique_email UNIQUE (email)
);

CREATE TABLE country (
    country_id NUMBER,
    -- ISO 3166 Alpha-3 Code
    code VARCHAR2(3),
    -- E.164 Code
    ddi VARCHAR2(3),
    name VARCHAR2(30),
    locked NUMBER(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pk_country_id PRIMARY KEY (country_id),
    CONSTRAINT unique_code UNIQUE (code)
);

CREATE TABLE state (
    state_id NUMBER,
    country_id NUMBER,
    name VARCHAR2(30),
    locked NUMBER(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pk_state_id PRIMARY KEY (state_id),
    CONSTRAINT fk_state_country_id 
        FOREIGN KEY (country_id) REFERENCES country(country_id)
);

CREATE TABLE city (
    city_id NUMBER,
    state_id NUMBER,
    name VARCHAR2(30),
    locked NUMBER(1) DEFAULT 0 NOT NULL,
    CONSTRAINT pk_city_id PRIMARY KEY (city_id),
    CONSTRAINT fk_city_state_id
        FOREIGN KEY (state_id) REFERENCES state(state_id)
);

CREATE TABLE address (
    address_id NUMBER,
    user_id NUMBER,
    country_id NUMBER,
    state_id NUMBER,
    city_id NUMBER,
    street_name VARCHAR2(60),
    zip_code VARCHAR2(8),
    CONSTRAINT pk_address_id PRIMARY KEY (address_id),
    CONSTRAINT fk_address_user_id
        FOREIGN KEY (user_id) REFERENCES end_user(user_id),
    CONSTRAINT fk_address_country_id
        FOREIGN KEY (country_id) REFERENCES country(country_id),
    CONSTRAINT fk_address_state_id
        FOREIGN KEY (state_id) REFERENCES state(state_id),
    CONSTRAINT fk_address_city_id
        FOREIGN KEY (city_id) REFERENCES city(city_id)
);

CREATE TABLE product (
    product_id NUMBER,
    user_id NUMBER,
    name VARCHAR2(30),
    description VARCHAR2(120),
    category VARCHAR2(16),
    model VARCHAR2(20),
    units NUMBER,
    unit_price NUMBER,
    CONSTRAINT pk_product_id PRIMARY KEY (product_id),
    CONSTRAINT fk_product_user_id
        FOREIGN KEY (user_id) REFERENCES end_user(user_id),
    CONSTRAINT check_category 
        CHECK (category IN ('INFORMATICA','ELETRODOMESTICOS', 'ALIMENTOS', 'OUTRO'))
);

CREATE TABLE shopping_cart (
    user_id NUMBER,
    product_id NUMBER,
    quantity NUMBER,
    total_price NUMBER,
    CONSTRAINT fk_cart_user_id
        FOREIGN KEY (user_id) REFERENCES end_user(user_id),
    CONSTRAINT fk_cart_product_id
        FOREIGN KEY (product_id) REFERENCES product(product_id)
);

CREATE TABLE orders (
    order_id NUMBER,
    user_id NUMBER,
    product_id NUMBER,
    quantity NUMBER,
    total_price NUMBER,
    created_at DATE DEFAULT CURRENT_DATE,
    payment_method VARCHAR2(20) NOT NULL,
    CONSTRAINT pk_orders_id PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_user_id
        FOREIGN KEY (user_id) REFERENCES end_user(user_id),
    CONSTRAINT fk_orders_product_id
        FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT check_payment_method
        CHECK (payment_method IN ('CREDIT_CARD','DEBIT_CARD','BANK_SLIP'))
);
