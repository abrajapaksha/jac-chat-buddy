import:py random;
import:py from jaclang.core.llms, Anthropic;

#anthropic key here .........................
glob llm = Anthropic(model_name="claude-3-sonnet-20240229");


node user{
    
    has user_name:string="user";
    
}


node session{
    has session_id : string = 100;
    has user_data : dict = {}; # User data such as habits, heart rate etc.
    has todo_list : list = []; # List of things to do by the user.
}


node data{
    has user_data:dict = {     #any data can add 
                "age" : 0,
                "Pressure" : (0,0),
                "Married" : False
                };
}


node todo{                       #can give any to does 
    has todo_list:list = [];
}



walker chat{             #to create the session node 

    can create_session with user entry;



    can chat_session with session entry;

}


walker create_graph{
    has user_data:dict = {};
    has todo_list:list = [];

    can generate_graph with `root entry;

}
walker query{
    has query:str = '';
    has user_session_id:str='';
    has session_chat_history:list=[];
    has user_data: 'data about the health status of the user' :dict={};
    has todo_list: 'The tasks to be done by the user in the future.' :list=[];

    can init_query_engine with session entry;

    
}

node router{

    can route with query entry;

    
}

node RAG_chat{
    can run_RAG with query entry{
        print('routed --> RAG');
    }

    
}

node user_qa_chat{
    can run_user_qa with query entry{
         print('routed --> USER_QA');
    }
}

node todo_chat{
    can run_todo_chat with query entry{
        print('routed --> TODO');
        print(self.chat_llm(todo_list=here.todo_list,query=here.query));
    }
        can 'You are a Health Assistant. Give a response based on the query using my todo list.'
    chat_llm(todo_list:'data about the health status of the user':list,
             query:'The tasks to be done by the user in the future.':str) -> 'response':str by llm();
}

with entry {
    create_graph(   user_data={ "age": 20,
                                "Pressure": (120, 80),
                                "Married": False
                            },
                     todo_list=["Do heart surgery : 04/12/2020",
                                "Run Marathon : 14/12/2020",
                                "Doctor's appointment : 20/12/2020"]
                ) spawn root;
}
## Implementations ==================================================================================================================

:walker:chat:can:create_session {

        # Telescope into the nodes connected to the user node without walking.
        data_node = [-->](`?data)[0]; # Getting the data node filtered. can use [0] as having only one such node.
        todo_node = [-->](`?todo)[0]; # Getting the todo node filtered. can use [0] as having only one such node.
        new_session_id = str(random.randint(1,100));

        # Creating a new session node with the user data and todo list and connect it to the user.
        n = here ++> session(   session_id = new_session_id,
                            user_data = data_node.user_data,
                            todo_list = todo_node.todo_list
                        );
        visit n;
    }

:walker:chat:can:chat_session {
    # print(here.user_data);
    # print(here.todo_list);
    query() spawn here;
}

:walker:create_graph:can:generate_graph {
    end = here; # Assign the current root node (here) to end
    end ++> (end := user()); # Create a user node and connect it to the end node. Assign the new user node to the end.
    end ++> data(user_data = self.user_data); # Create a data node with the user data and connect it to the end node.
    end ++> todo(todo_list = self.todo_list); # Create a todo node with the todo list and connect it to the end node.
    chat() spawn [-->](`?user)[0]; # Spawn the chat walker with the user node.
}

:walker:query:can:init_query_engine {
    self.user_data:dict = here.user_data;
    self.todo_list:list = here.todo_list;
    self.task_type:str = input('What is the routing method : ');
    self.query:str = input('Enter your query : ');

    end = here;
    end ++> (end := router());
    end ++> RAG_chat();
    end ++> todo_chat();
    end ++> user_qa_chat();

    visit [-->];
}

:node:router:can:route {
    task:str = here.task_type;
    if task == 'RAG' {
        visit [-->](`?RAG_chat);
    } elif task == 'QA'{
        visit [-->](`?user_qa_chat);
    } elif task == 'TODO' {
        visit [-->](`?todo_chat);
    }
}