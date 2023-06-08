DELIMITER //

DROP PROCEDURE IF EXISTS createTodo //
CREATE PROCEDURE createTodo (title VARCHAR(512), focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    due DATE, scheduled DATE, recurringDays INT, details TEXT, OUT todoID INT)
BEGIN
    INSERT INTO todo (sort, title, focus, state, due, scheduled, recurringDays, details)
        VALUES (0, title, focus, state, due, scheduled, recurringDays, details);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP PROCEDURE IF EXISTS listTodos //
CREATE PROCEDURE listTodos ()
BEGIN
    SELECT id AS _id, completed, title, state, due
        FROM todo ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS showTodo //
CREATE PROCEDURE showTodo (id INT)
BEGIN
    SELECT * FROM todo WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS displayTodo //
CREATE PROCEDURE displayTodo (_id INT)
BEGIN
    SELECT title FROM todo WHERE todo.id = _id;
    SELECT completed FROM todo WHERE todo.id = _id;
    SELECT focus FROM todo WHERE todo.id = _id;
    SELECT state FROM todo WHERE todo.id = _id;
    SELECT due FROM todo WHERE todo.id = _id;
    SELECT scheduled, recurringDays FROM todo WHERE todo.id = _id;
    SELECT scheduled, recurringDays FROM todo WHERE todo.id = _id;
    SELECT project FROM todo WHERE todo.id = _id;
    SELECT details FROM todo WHERE todo.id = _id;
END //

DROP PROCEDURE IF EXISTS listProjects //
CREATE PROCEDURE listProjects ()
BEGIN
    SELECT DISTINCT project, project AS _project FROM todo;
END //

DROP PROCEDURE IF EXISTS modifyTodo //
CREATE PROCEDURE modifyTodo (_id INT, title VARCHAR(512), completed DATE, focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    due DATE, scheduled DATE, recurringDays INT,
    newProjectName VARCHAR(255), listProjects_project VARCHAR(255),
    details TEXT, OUT result VARCHAR(255))
BEGIN
    DECLARE grp VARCHAR(255);

    IF (newProjectName IS NOT NULL) THEN
        SET grp = newProjectName;
    ELSE
        SET grp = listProjects_project;
    END IF;

    UPDATE todo AS t SET
        t.title = title,
        t.completed = completed,
        t.focus = focus,
        t.state = state,
        t.due = due,
        t.scheduled = scheduled,
        t.recurringDays = recurringDays,
        t.project = grp,
        t.details = details
        WHERE t.id = _id;
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS quickEntry //
CREATE PROCEDURE quickEntry (title VARCHAR(512), OUT todoID INT)
BEGIN
    INSERT INTO todo (sort, focus, title)
        VALUES (0, 0, title);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP PROCEDURE IF EXISTS listTasksInState //
CREATE PROCEDURE listTasksInState (state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'))
BEGIN
    SELECT id AS _id, title, due, project
        FROM todo WHERE todo.state = state AND todo.completed IS NULL ORDER BY project, sort;
END //

DROP PROCEDURE IF EXISTS listInboxTasks //
CREATE PROCEDURE listInboxTasks ()
BEGIN
    SELECT id AS _id, title
        FROM todo WHERE todo.state IS NULL AND todo.scheduled IS NULL ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS listFocusTasks //
CREATE PROCEDURE listFocusTasks ()
BEGIN
    SELECT id AS _id, title, due
        FROM todo WHERE todo.focus = 1 AND completed IS NULL ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS listCompletedTasks //
CREATE PROCEDURE listCompletedTasks ()
BEGIN
    SELECT id AS _id, title, completed
        FROM todo WHERE todo.completed IS NOT NULL ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS listScheduledTasks //
CREATE PROCEDURE listScheduledTasks ()
BEGIN
    SELECT id AS _id, title, scheduled, recurringDays
        FROM todo WHERE todo.scheduled IS NOT NULL ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS listTasksForProject //
CREATE PROCEDURE listTasksForProject (listProjects_project VARCHAR(255))
BEGIN
    SELECT id AS _id, title, due
        FROM todo WHERE todo.project = listProjects_project ORDER BY state, sort;
END //

DROP PROCEDURE IF EXISTS markCompleted //
CREATE PROCEDURE markCompleted (id INT)
BEGIN
    UPDATE todo SET completed = CURDATE() WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS toggleFocus //
CREATE PROCEDURE toggleFocus (id INT)
BEGIN
    UPDATE todo SET focus = !focus WHERE todo.id = id;
END //

