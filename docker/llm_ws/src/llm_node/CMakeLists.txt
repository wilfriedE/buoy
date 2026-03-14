cmake_minimum_required(VERSION 3.8)
project(llm_node)

find_package(ament_cmake REQUIRED)

# Install Python package (for imports)
install(DIRECTORY llm_node/
  DESTINATION lib/python3.12/site-packages/llm_node
  USE_SOURCE_PERMISSIONS
)

# Install executable for ros2 run llm_node llm_node
install(PROGRAMS llm_node/llm_node.py DESTINATION lib/${PROJECT_NAME} RENAME llm_node)

# Package index marker for ament
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/resource/${PROJECT_NAME}")
  install(FILES resource/${PROJECT_NAME}
    DESTINATION share/ament_index/resource_index/packages
  )
endif()
install(FILES package.xml DESTINATION share/${PROJECT_NAME})

ament_package()
