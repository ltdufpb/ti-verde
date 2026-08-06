from locust import HttpUser, task, between, SequentialTaskSet

class AdminBehavior(SequentialTaskSet):
    
    def on_start(self):
        response = self.client.get("/adminlogin")
        csrftoken = response.cookies.get('csrftoken', '')
        
        self.client.post("/adminlogin", {
            "username": "admin",
            "password": "admin123",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/adminlogin"})
    
    @task(3)
    def view_dashboard(self):
        self.client.get("/admin-dashboard")
    
    @task(2)
    def view_all_students(self):
        self.client.get("/admin-view-student")
    
    @task(2)
    def view_all_teachers(self):
        self.client.get("/admin-view-teacher")
    
    @task(1)
    def view_student_fees(self):
        self.client.get("/admin-view-student-fee")
    
    @task(1)
    def view_teacher_salary(self):
        self.client.get("/admin-view-teacher-salary")
    
    @task(2)
    def view_attendance(self):
        response = self.client.get("/admin-view-attendance/one")
        csrftoken = response.cookies.get('csrftoken', '')
        self.client.post("/admin-view-attendance/one", {
            "date": "2025-10-15",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/admin-view-attendance/one"})


class StudentBehavior(SequentialTaskSet):
    
    def on_start(self):
        response = self.client.get("/studentlogin")
        csrftoken = response.cookies.get('csrftoken', '')
        
        self.client.post("/studentlogin", {
            "username": "student_0",
            "password": "senha123",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/studentlogin"})
    
    @task(3)
    def view_dashboard(self):
        self.client.get("/student-dashboard")
    
    @task(2)
    def view_attendance(self):
        response = self.client.get("/student-attendance")
        csrftoken = response.cookies.get('csrftoken', '')
        self.client.post("/student-attendance", {
            "date": "2025-10-15",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/student-attendance"})


class TeacherBehavior(SequentialTaskSet):
    
    def on_start(self):
        response = self.client.get("/teacherlogin")
        csrftoken = response.cookies.get('csrftoken', '')
        
        self.client.post("/teacherlogin", {
            "username": "teacher_0",
            "password": "senha123",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/teacherlogin"})
    
    @task(3)
    def view_dashboard(self):
        self.client.get("/teacher-dashboard")
    
    @task(2)
    def view_attendance(self):
        response = self.client.get("/teacher-view-attendance/one")
        csrftoken = response.cookies.get('csrftoken', '')
        self.client.post("/teacher-view-attendance/one", {
            "date": "2025-10-15",
            "csrfmiddlewaretoken": csrftoken
        }, headers={"Referer": "http://localhost:8000/teacher-view-attendance/one"})


class SchoolUser(HttpUser):
    wait_time = between(1, 3)
    tasks = {
        AdminBehavior: 2,
        TeacherBehavior: 3,
        StudentBehavior: 5
    }
