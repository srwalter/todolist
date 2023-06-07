DELIMITER //

DROP PROCEDURE IF EXISTS createTodo //
CREATE PROCEDURE createTodo (title VARCHAR(512), focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    due DATE, scheduled DATE, recurringDays INT, details TEXT, OUT todoID INT)
BEGIN
    INSERT INTO todo (sort, complete, title, focus, state, due, scheduled, recurringDays, details)
        VALUES (0, 0, title, focus, state, due, scheduled, recurringDays, details);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP PROCEDURE IF EXISTS listTodos //
CREATE PROCEDURE listTodos ()
BEGIN
    SELECT id AS _id, complete, title, state, due
        FROM todo ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS showTodo //
CREATE PROCEDURE showTodo (id INT)
BEGIN
    SELECT * FROM todo WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS modifyTodo //
CREATE PROCEDURE modifyTodo (_id INT, title VARCHAR(512), complete tinyint(1), focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    due DATE, scheduled DATE, recurringDays INT, details TEXT, OUT result VARCHAR(255))
BEGIN
    UPDATE todo AS t SET
        t.title = title,
        t.complete = complete,
        t.focus = focus,
        t.state = state,
        t.due = due,
        t.scheduled = scheduled,
        t.recurringDays = recurringDays,
        t.details = details
        WHERE t.id = _id;
    SET result = "Success";
END //
