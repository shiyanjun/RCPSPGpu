/*
	This file is part of the RCPSPGpu program.

	RCPSPGpu is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	RCPSPGpu is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with RCPSPGpu. If not, see <http://www.gnu.org/licenses/>.
*/
#ifndef HLIDAC_PES_SCHEDULE_SOLVER_CUH
#define HLIDAC_PES_SCHEDULE_SOLVER_CUH

/*!
 * \file ScheduleSolver.cuh
 * \author Libor Bukata
 * \brief RCPSP solver class.
 */

#include <iostream>
#include <stdint.h>
#include "CudaFunctions.cuh"
#include "InputReader.h"
#include "ConfigureRCPSP.h"

/*!
 * Tabu search meta heuristic is used to solve RCPSP. GPU computing power is exploited for quicker solving of the problem.
 * \class ScheduleSolver
 * \brief Instance of this class is able to solve resource constrained project scheduling problem.
 */
class ScheduleSolver {
	//! A forward declaration of the InstanceData inner class.
	struct InstanceData;
	//! A forward declaration of the InstanceSolution inner class.
	struct InstanceSolution;

	public:
		/*!
		 * \param rcpspData Data of project instance.
		 * \param verbose If true then extra informations are printed.
		 * \exception runtime_error Cuda error occur.
		 * \brief Copy pointers of project data, initialize required structures, create initial activities order and copy data to GPU.
		 */
		ScheduleSolver(const InputReader& rcpspData, bool verbose = false);

		/*!
		 * \param maxIter Number of iterations that should be performed.
		 * \exception runtime_error Cuda error occur.
		 * \brief Use GPU version of tabu search to find good quality solution.
		 */
		void solveSchedule(const uint32_t& maxIter = ConfigureRCPSP::NUMBER_OF_ITERATIONS);
		/*!
		 * \param verbose If false then only result makespan, critical path makespan and computational time will be printed.
		 * \param output Output stream.
		 * \brief Print best found schedule, schedule length and computational time.
		 */
		void printBestSchedule(bool verbose = true, std::ostream& output = std::cout);
		/*!
		 * \param fileName The name of the file where results will be written.
		 * \exception invalid_argument The output file cannot be created, check the permissions.
		 * \brief It writes required data structures and the best schedule to the given file.
		 */
		void writeBestScheduleToFile(const std::string& fileName);

		//! Free all allocated resources (CPU + GPU).
		~ScheduleSolver();

	protected:

		/*!
		 * \param project The data-structure of the read instance.
		 * \param solution The data-structure which stores an initial solution of the project instance.
		 * \brief It initialises auxiliary data-structures of the read instance and creates the initial solution.
		 */
		static void initialiseInstanceDataAndInitialSolution(InstanceData& project, InstanceSolution& solution);
		/*!
		 * \param project The data of the read instance.
		 * \param solution An initial order will be written to this data-structure.
		 * \brief An initial order of activities is created using precedence graph stored in the project data-structure.
		 */
		static void createInitialSolution(const InstanceData& project, InstanceSolution& solution);
		
		/*!
		 * \param out The output stream where the instance data and the solution will be written.
		 * \param project The project instance data that will be written to the output file.
		 * \param solution The solution of the given project.
		 * \return A reference to the output stream.
		 * \brief The method writes the instance data and solution of the instance.
		 */
		static std::ofstream& writeBestScheduleToFile(std::ofstream& out, const InstanceData& project, const InstanceSolution& solution);
		
		/*!
		 * \param project A read RCPSP project.
		 * \param solution An initial solution of the read project.
		 * \param verbose If true then more informations (Cuda info, etc.) will be showed.
		 * \return Return true if some Cuda error will be detected.
		 * \brief Copy required data to GPU and compute a critical path makespan.
		 */
		bool prepareCudaMemory(const InstanceData& project, InstanceSolution& solution, bool verbose);
		/*!
		 * \param numberOfSetSolutions The number of solutions in the GPU solution set.
		 * \return Return true if a cuda error occurs.
		 * \brief It creates static tree from which the initial solutions are generated. These solutions are loaded to GPU memory.
		 */
		bool loadInitialSolutionsToGpu(const uint16_t& numberOfSetSolutions);
		/*!
		 * \param phase Number that correspond to a location at prepareCudaMemory method.
		 * \return Always return true.
		 * \brief Print error message, free Cuda allocated resources and return true.
		 */
		bool errorHandler(int16_t phase);
		
		/*!
		 * \param startActivityId The id of the start activity of the project.
		 * \param project The project instance in which the longest paths are computed.
		 * \param energyReasoning The energy requirements are taken into account if energyReasoning variable is set to true.
		 * \return The earliest start time for each activity.
		 * \brief Lower bounds of the earliest start time values are computed for each activity.
		 * \warning The user is responsible for freeing the allocated memory in the returned array.
		 */
		static uint16_t* computeLowerBounds(const uint16_t& startActivityId, const InstanceData& project, const bool& energyReasoning = false);
		
		/*!
		 * \param project The data of the instance. (activity duration, precedence edges, ...)
		 * \param solution The current solution of the project. The order is evaluated.
		 * \param timeValuesById The earliest start time values for forward evaluation and transformed time values for backward evaluation.
		 * \param forwardEvaluation It determines if forward or backward schedule is evaluated.
		 * \return Length of the schedule.
		 * \brief Input order is evaluated and the earliest start/transformed time values are computed.
		 * \warning Order of activities is sequence of putting to the schedule, time values don't have to be ordered.
		 */
		static uint16_t evaluateOrder(const InstanceData& project, const InstanceSolution& solution, uint16_t *& timeValuesById, bool forwardEvaluation);

		/*!
		 * \param project The data of the instance.
		 * \param solution Current solution of the instance.
		 * \param startTimesById The earliest start time values for each scheduled activity.
		 * \return Project makespan, i.e. the length of the schedule.
		 * \brief It evaluates order of activities and determines the earliest start time values.
		 */
		static uint16_t forwardScheduleEvaluation(const InstanceData& project, const InstanceSolution& solution, uint16_t *& startTimesById);
		/*!
		 * \param project The data-structure of the instance.
		 * \param solution Current solution of the instance.
		 * \param startTimesById The latest start time values for each scheduled activity.
		 * \return Project makespan, i.e. the length of the schedule.
		 * \brief It evaluates order (in reverse order) of activities and determines the latest start time values.
		 */
		static uint16_t backwardScheduleEvaluation(const InstanceData& project, const InstanceSolution& solution, uint16_t *& startTimesById);
		/*!
		 * \param project The data-structure of the instance.
		 * \param solution Current solution of the instance.
		 * \param bestScheduleStartTimesById The earliest start time values for the best found schedule.
		 * \return Project makespan, i.e. the length of the schedule.
		 * \brief Iterative method tries to shake down activities in the schedule to ensure equally loaded resources.
		 * Therefore, the shorter schedule could be found.
		 */
		static uint16_t shakingDownEvaluation(const InstanceData& project, const InstanceSolution& solution, uint16_t *bestScheduleStartTimesById);
		
		/*!
		 * \param project The data of the instance.
		 * \param startTimesById Start time values of activities ordered by ID's.
		 * \return Precedence penalty of the schedule.
		 * \brief Method compute precedence penalty (= broken relation between two activities) of the schedule.
		 * \note Because precedence free swaps and shifts are currently used, this function is only for debugging purposes.
		 */
		static uint16_t computePrecedencePenalty(const InstanceData& project, const uint16_t * const& startTimesById);
		/*!
		 * \param project The data of the project.
		 * \param solution A solution of the project.
		 * \param i Index at activitiesOrder.
		 * \param j Index at activitiesOrder.
		 * \return True if and only if precedence penalty is zero else false.
		 * \brief Method check if candidate for swap is precedence penalty free.
		 */
		static bool checkSwapPrecedencePenalty(const InstanceData& project, const InstanceSolution& solution, uint16_t i, uint16_t j);

		/*!
		 * \param project The data of the instance.
		 * \param solution Current solution of the instance.
		 * \param startTimesById The earliest start time values in the order W.
		 * \brief It transforms the earliest start time values to the order W. The order W is written to the variable solution.orderOfActivities.
		 */
		static void convertStartTimesById2ActivitiesOrder(const InstanceData& project, InstanceSolution& solution, const uint16_t * const& startTimesById);
		/*!
		 * \param project The data of the instance.
		 * \param solution Current solution of the instance.
		 * \param timeValuesById Assigned time values to activities, it is used for sorting input order.
		 * \brief Input order of activities is sorted in accordance with time values. It's stable sort.
		 */
		static void insertSort(const InstanceData& project, InstanceSolution& solution, const uint16_t * const& timeValuesById);
		
		/*!
		 * \param project The data of the printed instance.
		 * \param solution The solution of the instance.
		 * \param runTime The computation time at seconds.
		 * \param evaluatedSchedules The number of evaluated schedules during execution.
		 * \param verbose If true then verbose mode is turn on.
		 * \param output Output stream.
		 * \brief Print schedule, schedule length, precedence penalty and number of evaluated schedules.
		 */
		static void printSchedule(const InstanceData& project, const InstanceSolution& solution, double runTime, uint64_t evaluatedSchedules, bool verbose = true, std::ostream& output = std::cout);

		/*!
		 * \param project The data of the instance.
		 * \param solution A solution in which a diversification will be performed.
		 * \brief Random swaps are performed when diversification is called..
		 */
		static void makeDiversification(const InstanceData& project, InstanceSolution& solution);

		/*!
		 * \param project The data of the project instance.
		 * \brief The method swaps directions of all precedence edges in the project data-structure.
		 */
		static void changeDirectionOfEdges(InstanceData& project);
		
		/*!
		 * \param activityId The activity from which all related activities are found.
		 * \param numberOfRelated The number of related activities for each activity.
		 * \param related The related (= successors || predecessors) activities for each activity in the project.
		 * \param numberOfActivities The total number of activities in the project.
		 * \return It returns all activityId's successors or predecessors.
		 * \warning It is your responsibility for freeing allocated memory of the returned vector.
		 */
		static std::vector<uint16_t>* getAllRelatedActivities(uint16_t activityId, uint16_t *numberOfRelated, uint16_t **related, uint16_t numberOfActivities);
		/*!
		 * \param activityId Identification of the activity.
		 * \param project The data of the project.
		 * \return It returns all activityId's successors.
		 * \warning It is your responsibility for freeing allocated memory of the returned vector.
		 */
		static std::vector<uint16_t>* getAllActivitySuccessors(const uint16_t& activityId, const InstanceData& project);
		/*!
		 * \param activityId Identification of the activity.
		 * \param project The data of the project.
		 * \return It returns all activityId's predecessors.
		 * \warning It is your responsibility for freeing allocated memory of the returned vector.
		 */
		static std::vector<uint16_t>* getAllActivityPredecessors(const uint16_t& activityId, const InstanceData& project);	

		/*!
		 * \param array The read-only array which will be copied.
		 * \param length The length of the array.
		 * \return The converted copy of the input array.
		 */
		template<class X, class Y>
		static Y* convertArrayType(X* array, size_t length);

	private:

		/* COPY OBJECT IS FORBIDDEN */

		//! Copy constructor is forbidden.
		ScheduleSolver(const ScheduleSolver&);
		//! Assignment operator is forbidden.
		ScheduleSolver& operator=(const ScheduleSolver&);

		/* IMMUTABLE DATA */
		
		//! A static parameters of a RCPSP project.
		struct InstanceData	{
			//! Number of renewable sources.
			uint8_t numberOfResources;
			//! The capacity of the resources.
			uint8_t *capacityOfResources;
			//! Total number of activities.
			uint16_t numberOfActivities;
			//! Duration of activities.
			uint8_t *durationOfActivities;
			//! Activities successors;
			uint16_t **successorsOfActivity;
			//! Number of successors that activities.
			uint16_t *numberOfSuccessors;
			//! Precomputed predecessors.
			uint16_t **predecessorsOfActivity;
			//! Number of predecessors.
			uint16_t *numberOfPredecessors;
			//! Sources that are required by activities.
			uint8_t **requiredResourcesOfActivities;
			//! Critical Path Makespan. (Critical Path Method)
			int32_t criticalPathMakespan;
			//! The longest paths from the end activity in the transformed graph.
			uint16_t *rightLeftLongestPaths;
			//! Upper bound of Cmax (sum of all activity durations).
			uint16_t upperBoundMakespan;
			//! All successors of an activity. Cache purposes.
			std::vector<std::vector<uint16_t>*> allSuccessorsCache;
			//! All predecessors of an activity. Cache purposes.
			std::vector<std::vector<uint16_t>*> allPredecessorsCache;
		};

		//! The data of the read instance.
		InstanceData instance;
		

		/* MUTABLE DATA */	

		//! A solution of a project is stored in this structure.
		struct InstanceSolution	{
			//! Current activities order.
			uint16_t *orderOfActivities;
			//! Best schedule order.
			uint16_t *bestScheduleOrder;
			//! Cost of the best schedule.
			uint16_t costOfBestSchedule;
		};

		//! The current solution of the read instance.
		InstanceSolution instanceSolution;

		/* CUDA DATA */

		//! All required informations are passed through this variable to Cuda global function. For example pointers to device memory, integer parameters etc.
		CudaData cudaData;
		//! Cuda capability of selected graphics card. (for example value 130 correspond to capability 1.3)
		uint16_t cudaCapability;
		//! Number of blocks that should be launched on GPU.
		uint16_t numberOfBlock;
		//! Required amount of dynamic share memory allocation at GPU.
		uint32_t dynSharedMemSize;
		//! How many threads should be launched per one block.
		uint32_t numberOfThreadsPerBlock;

		//! Texture array of activities resource requirements.
		uint8_t *cudaActivitiesResourcesArray;
		//! Texture array of predecessors.
		uint16_t *cudaPredecessorsArray;
		//! Texture array of predecessors indices.
		uint16_t *cudaPredecessorsIdxsArray;
		

		/* MISC DATA */
		
		//! Purpose of this variable is to remember total computational time.
		double totalRunTime;
		//! Number of evaluated schedules on the GPU.
		uint64_t numberOfEvaluatedSchedules;
};

#endif

